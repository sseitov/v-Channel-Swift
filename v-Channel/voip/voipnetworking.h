//
//  voipnetworking.h
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#ifndef __VOIPNETWORKING_H_
#define __VOIPNETWORKING_H_

#include <dispatch/dispatch.h>

#include "voipcrypto.h"
#include "voipcodec.h"
#include "voipringbuffer.h"

#define INPUT_BUFFER_SIZE 1920

typedef struct vcNetworkingReceiverContext vcNetworkingReceiverContext;

typedef struct vcNetworkingSenderContext vcNetworkingSenderContext;

typedef void (*receiver_callback_t)(void);

int create_socket(const char *host, const char *port, int server);

vcNetworkingSenderContext *vcNetworkingSenderCreate(const char *host, const char *port, uint8_t senderId, int silence,vcRingBuffer *ringBuffer, vcEncryptor *encryptor, vcEncoder *encoder);
size_t vcNetworkingSenderGetSent(vcNetworkingSenderContext *context);
int vcNetworkingSenderGetSocket(vcNetworkingSenderContext *context);
void vcNetworkingSenderStart(vcNetworkingSenderContext *context);
void vcNetworkingSenderDestroy(vcNetworkingSenderContext *context);

vcNetworkingReceiverContext *vcNetworkingReceiverCreateWithSocket(int socket, int videoSocket, vcRingBuffer **ringBuffer, uint8_t ringBufferCount);
size_t vcNetworkingReceiverGetReceived(vcNetworkingReceiverContext *context);
void vcNetworkingReceiverStart(vcNetworkingReceiverContext *context, receiver_callback_t start, receiver_callback_t finish);
void vcNetworkingReceiverDestroy(vcNetworkingReceiverContext *context);

#endif
