//
//  voipnetworking.c
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#include "voipnetworking.h"

#include <CommonCrypto/CommonCrypto.h>
#include <Security/Security.h>
#include <libkern/OSAtomic.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <poll.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

#include <opus/opus.h>

#define SAMPLE_RATE 48000.0
#define CHANNELS_PER_FRAME 1
#define AUDIO_PACKET 30
#define VIDEO_PACKET 12

#define ARRAYSZ(a) (sizeof(a)/sizeof(*(a)))

struct vcNetworkingReceiverContext {
    int socket;
    vcRingBuffer **ringBuffer;
    uint8_t ringBufferCount;
    
    dispatch_queue_t dispatchQueue;
    int32_t stopped;
    pthread_mutex_t destructionMutex;
    
    size_t received;
};

struct vcNetworkingSenderContext {
    int socket;
    vcRingBuffer *ringBuffer;
    vcEncryptor *encryptor;
    
    int16_t buffer[INPUT_BUFFER_SIZE];
    int32_t buffer_offset_samples;
    
    vcEncoder *encoder;
    
    dispatch_queue_t dispatchQueue;
    int32_t stopped;
    pthread_mutex_t destructionMutex;
    
    size_t sent;
    uint8_t senderId;
    int silenceSuppression;
};

static int create_socket(const char *host, const char *port, int server);

vcNetworkingSenderContext *vcNetworkingSenderCreate(const char *host, const char *port, uint8_t senderId, int silenceSupression, vcRingBuffer *ringBuffer, vcEncryptor *encryptor, vcEncoder *encoder) {
    vcNetworkingSenderContext *context = calloc(1, sizeof(*context));
    context->socket = create_socket(host, port, 0);
    fprintf(stderr, "Trying to create a socket on %s %s\n", host, port);
    if(context->socket == -1) {
        fprintf(stderr, "Socket creation failed.\n");
        goto error;
    }
    
    context->ringBuffer = ringBuffer;
    context->encryptor = encryptor;
    context->encoder = encoder;
    context->sent = 0;
    context->senderId = senderId;
    pthread_mutex_init(&context->destructionMutex, NULL);
    context->stopped = 1;
    context->silenceSuppression = silenceSupression;
    goto success;
error:
    close(context->socket);
    free(context);
    context = NULL;
success:
    return context;
}

size_t vcNetworkingSenderGetSent(vcNetworkingSenderContext *context) {
    return context->sent;
}

int vcNetworkingSenderGetSocket(vcNetworkingSenderContext *context) {
    return context->socket;
}

static int min(int a, int b) {
    return a < b ? a : b;
}

static void send_frames(vcNetworkingSenderContext *context, int16_t *audio_frames, uint32_t audio_frames_sample_count) {
    uint32_t audio_frames_offset_samples = 0;
    
    while (audio_frames_offset_samples < audio_frames_sample_count) {
        int recorderBufferSpaceLeft = ARRAYSZ(context->buffer) - context->buffer_offset_samples;
        int audioFramesLeft = audio_frames_sample_count - audio_frames_offset_samples;
        int samples_to_copy = min(recorderBufferSpaceLeft, audioFramesLeft);
        
        memcpy(context->buffer + context->buffer_offset_samples,
               audio_frames + audio_frames_offset_samples,
               2 * samples_to_copy);
        
        audio_frames_offset_samples += samples_to_copy;
        context->buffer_offset_samples += samples_to_copy;
        
        if (ARRAYSZ(context->buffer) == context->buffer_offset_samples) {
            context->buffer_offset_samples = 0;
            
            if(!vcEncode(context->encoder, context->buffer, sizeof(context->buffer)/2)) {
//                fprintf(stderr, "Encoding failed.\n");
                continue;
            }
            
//            fprintf(stderr, "Encoded to %zu bytes\n", context->encoder->outputBufferLength);
            
            unsigned char iv[16];
            int err = SecRandomCopyBytes(kSecRandomDefault, 16, iv);
            
            if (err == 0) {
                vcEncryptorEncrypt(context->encryptor,
                                   context->encoder->outputBuffer,
                                   context->encoder->outputBufferLength,
                                   iv);
                
                // TODO this can probably be optimized *cough*
                uint8_t entirePacket[INPUT_BUFFER_SIZE+2];
                entirePacket[0] = context->senderId;
                entirePacket[1] = AUDIO_PACKET;
                
                memcpy(entirePacket+2, context->encryptor->encrypted, context->encryptor->encryptedLength);
                size_t entirePacketLength = context->encryptor->encryptedLength+1;
                ssize_t written = write(context->socket, entirePacket, entirePacketLength);
                context->sent += written;
            }
        }
    }
}

void vcNetworkingSenderStart(vcNetworkingSenderContext *context) {
    context->dispatchQueue = dispatch_queue_create("vcNetworkingSender", DISPATCH_QUEUE_SERIAL);
    dispatch_async(context->dispatchQueue, ^{
        pthread_mutex_lock(&context->destructionMutex);
        
        uint8_t entirePacket[INPUT_BUFFER_SIZE+2];
        entirePacket[0] = context->senderId;
        entirePacket[1] = AUDIO_PACKET;
        memcpy(entirePacket+2, "START", 5);
        size_t entirePacketLength = 7;
        write(context->socket, entirePacket, entirePacketLength);

        context->stopped = 0;
        
        // TODO: read s topped atomically somehow?
        while (!context->stopped) {
            vcRingBufferConsumerWait(context->ringBuffer);
            if(context->stopped) {
                break;
            }
            uint8_t *data = vcRingBufferConsumerGetCurrent(context->ringBuffer);
            size_t dataSize = vcRingBufferConsumerGetCurrentSize(context->ringBuffer);
            // TODO: int16_t should not be hardcoded here.
            send_frames(context, (int16_t*)data, (uint32_t)(dataSize/sizeof(int16_t)));
            vcRingBufferConsumerConsumed(context->ringBuffer);
        }
        
        fprintf(stderr, "Stopping sender thread\n");
        
        pthread_mutex_unlock(&context->destructionMutex);
    });
}

void vcNetworkingSenderDestroy(vcNetworkingSenderContext *context)
{
    if (context != NULL) {
        bool wasRunning = OSAtomicCompareAndSwap32Barrier(0, 1, &context->stopped);
        context->stopped = true;
        
        uint8_t entirePacket[INPUT_BUFFER_SIZE+2];
        entirePacket[0] = context->senderId;
        entirePacket[1] = AUDIO_PACKET;
        memcpy(entirePacket+2, "STOP", 4);
        size_t entirePacketLength = 6;
        write(context->socket, entirePacket, entirePacketLength);

        if (wasRunning) {
            pthread_mutex_lock(&context->destructionMutex);
        }
        
        if (context->dispatchQueue != NULL) {
            // TODO: actually stop the thread
            dispatch_release(context->dispatchQueue);
        }
        
        close(context->socket);
        
        if (wasRunning) {
            pthread_mutex_unlock(&context->destructionMutex);
        }
        
        pthread_mutex_destroy(&context->destructionMutex);
        free(context);
    }
}

vcNetworkingReceiverContext *vcNetworkingReceiverCreate(const char *port, vcRingBuffer **ringBuffer, uint8_t ringBufferCount) {
    
    int socket = create_socket("", port, 1);
    if(socket == -1) {
        fprintf(stderr, "Socket creation failed.\n");
        return NULL;
    }
    return vcNetworkingReceiverCreateWithSocket(socket, ringBuffer, ringBufferCount);
}

vcNetworkingReceiverContext *vcNetworkingReceiverCreateWithSocket(int socket, vcRingBuffer **ringBuffer, uint8_t ringBufferCount) {
    vcNetworkingReceiverContext *context = calloc(1, sizeof(vcNetworkingReceiverContext));
    context->socket = socket;
    context->ringBuffer = ringBuffer;
    context->ringBufferCount = ringBufferCount;
    pthread_mutex_init(&context->destructionMutex, NULL);
    context->stopped = 1;
    context->received = 0;
    return context;
}

size_t vcNetworkingReceiverGetReceived(vcNetworkingReceiverContext *context) {
    return context->received;
}

void vcNetworkingReceiverStart(vcNetworkingReceiverContext *context, receiver_callback_t start, receiver_callback_t finish) {
    
    context->dispatchQueue = dispatch_queue_create("vcNetworkingReceiver", DISPATCH_QUEUE_SERIAL);
    dispatch_async(context->dispatchQueue, ^{
        struct pollfd pollfds[] = {
            { context->socket, POLLIN, 0 }
        };
        
        pthread_mutex_lock(&context->destructionMutex);
        
        context->stopped = 0;
        
        uint8_t buffer[VC_RINGBUFFER_CELL_SIZE];
        
        // TODO: read stopped atomically somehow?
        while (!context->stopped) {
            int pret = poll(pollfds, 1, 16);
            if (pret == -1) {
                fprintf(stderr, "socket error\n");
                break;
            }
            else if (pret == 0) {
                continue;
            }
            ssize_t result = read(context->socket, buffer, VC_RINGBUFFER_CELL_SIZE);
            
            if (result > 0) {
                uint8_t ringBufferId = buffer[0];
                uint8_t contentId = buffer[1];
                if (contentId == AUDIO_PACKET) {
                    if(ringBufferId >= context->ringBufferCount) {
                        fprintf(stderr, "GOT DATA FOR INVALID RINGBUFFER (%d of %d)", ringBufferId, context->ringBufferCount);
                        continue;
                    }
                    
                    if (buffer[2] == 'S' && buffer[3] == 'T' && buffer[4] == 'O' && buffer[5] == 'P') {
                        finish();
                        context->stopped = true;
                    } else if (buffer[2] == 'S' && buffer[3] == 'T' && buffer[4] == 'A' && buffer[5] == 'R' && buffer[6] == 'T') {
                        start();
                    } else {
                        uint8_t *targetBuffer = vcRingBufferProducerGetCurrent(context->ringBuffer[ringBufferId]);
                        context->received += result;
                        memcpy(targetBuffer, buffer+2, result-2);
                        vcRingBufferProducerProduced(context->ringBuffer[ringBufferId], result);
                    }
                }
            }
            else if (result == -1 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
                continue;
            }
            else {
                context->stopped = true;
            }
        }
        
        fprintf(stderr, "Stopping receiver thread\n");
        
        pthread_mutex_unlock(&context->destructionMutex);
    });
}

void vcNetworkingReceiverDestroy(vcNetworkingReceiverContext *context) {
    if (context != NULL) {
        bool wasRunning = OSAtomicCompareAndSwap32Barrier(0, 1, &context->stopped);
        
        if (wasRunning) {
            pthread_mutex_lock(&context->destructionMutex);
        }
        
        close(context->socket);
        if (context->dispatchQueue != NULL) {
            dispatch_release(context->dispatchQueue);
        }
        
        if (wasRunning) {
            pthread_mutex_unlock(&context->destructionMutex);
        }
        
        pthread_mutex_destroy(&context->destructionMutex);
    }
    free(context);
}

static int create_socket(const char *host, const char *port, int server)
{
    int sock = 0, error;
    struct addrinfo hints, *result = NULL, *r;
    int (*func)(int, const struct sockaddr*, socklen_t) = server ? bind : connect;
    
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_protocol = 0;
    hints.ai_flags = server ? AI_PASSIVE : 0;
    
    error = getaddrinfo(host, port, &hints, &result);
    if (error != 0) {
        // TODO: We probably want to remove this errx
        fprintf(stderr, "getaddrinfo error: %s\n", gai_strerror(error));
        return -1;
    }
    
    for (r = result; r; r = r->ai_next) {
        sock = socket(r->ai_family, r->ai_socktype, r->ai_protocol);
        
        if (sock == -1)
            continue;
        
        if (func(sock, r->ai_addr, r->ai_addrlen) == 0)
            break;
        
        close(sock);
    }
    
    if (!r) {
        fprintf(stderr, "%s error: %s\n", sock == -1 ? "socket" : server ? "bind" : "connect", strerror(errno));
        sock = -1;
    }
    
    if (sock != -1) {
        fcntl(sock, F_SETFL, O_NONBLOCK);
    }
    
    if (result != NULL) {
        freeaddrinfo(result);
    }
    
    return sock;
}
