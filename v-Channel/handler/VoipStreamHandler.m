//
//  VoipStreamHandler.m
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import "VoipStreamHandler.h"

#include <CommonCrypto/CommonCrypto.h>
#import <AVFoundation/AVFoundation.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <poll.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

#define VC_VIDEO_BUFFER_SIZE 16384

@implementation VoipStreamHandler

NSString *const NOTIFICATION_CALL_STREAM_ROUTING_UPDATE = @"com.vchannel.upwork.SimpleVOIP";

+ (VoipStreamHandler *)sharedInstance
{
    static VoipStreamHandler *sharedInstance = nil;
    static dispatch_once_t pred;
    
    dispatch_once(&pred, ^{
        sharedInstance = [[VoipStreamHandler alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance
                                                 selector:@selector(audioSessionRouteChanged:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:sharedInstance
                                                 selector:@selector(audioSessionInterrupted:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:nil];
    });
    
    return sharedInstance;
}

- (BOOL)isLoudSpeaker
{
    AVAudioSessionRouteDescription* route = [AVAudioSession sharedInstance].currentRoute;
    if (route.outputs.count < 1) {
        return NO;
    }
    AVAudioSessionPortDescription* currentPort = [route.outputs objectAtIndex:0];
    NSString *uid = [currentPort.UID lowercaseString];
    return ([uid rangeOfString:@"speaker"].location != NSNotFound);
}

- (void)audioSessionInterrupted:(NSNotification*)notification
{
    AVAudioSessionInterruptionType type = [[[notification userInfo] objectForKey:AVAudioSessionInterruptionTypeKey] integerValue];
    AVAudioSessionInterruptionOptions options = [[[notification userInfo] objectForKey:AVAudioSessionInterruptionOptionKey] integerValue];
    switch (type) {
        case AVAudioSessionInterruptionTypeBegan:
            NSLog(@"put in hold");
            break;
        case AVAudioSessionInterruptionTypeEnded:
            if (options == AVAudioSessionInterruptionOptionShouldResume) {
                NSLog(@"restore");
                [self startVoIP];
            }
            break;
        default:
            break;
    }
}

- (void)audioSessionRouteChanged:(NSNotification*)notification
{
    NSInteger  reason = [[[notification userInfo] objectForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    switch (reason) {
        case AVAudioSessionRouteChangeReasonNoSuitableRouteForCategory:
            NSLog(@"The route changed because no suitable route is now available for the specified category.");
            return;
        case AVAudioSessionRouteChangeReasonWakeFromSleep:
            NSLog(@"The route changed when the device woke up from sleep.");
            return;
        case AVAudioSessionRouteChangeReasonOverride:
            NSLog(@"The output route was overridden by the app.");
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:
            NSLog(@"The category of the session object changed.");
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            NSLog(@"The previous audio output path is no longer available.");
            return;
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            NSLog(@"A preferred new audio output path is now available.");
            break;
        case AVAudioSessionRouteChangeReasonUnknown:
        default:
            NSLog(@"The reason for the change is unknown.");
            return;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_CALL_STREAM_ROUTING_UPDATE object:nil];
}

- (void)enableLoudspeaker:(bool)speaker
{
    NSError *error;
    for(int i=0; i < receiverCount; i++) {
        vcCoreAudioOutputDestroy(audioOutputs[i]);
    }
    vcCoreAudioInputDestroy(audioInput);
    audioInput = nil;
    if(speaker) {
        if (![self isLoudSpeaker]) {
            [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
        }
    } else {
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
    }
    vcRingBufferClear(senderRingBuffer);
    audioInput = vcCoreAudioInputCreate(senderRingBuffer, encryptor);
    vcCoreAudioInputStart(audioInput);
    for(int i=0; i < receiverCount; i++) {
        audioOutputs[i] = vcCoreAudioOutputCreate(receiverRingBuffers[i], decryptors[i], decoders[i]);
        vcCoreAudioOutputStart(audioOutputs[i]);
    }
}

- (void)openWithGateway:(CallGatewayInfo*)audioGateway videoGateway:(CallGatewayInfo*)videoGateway ReceiverCount:(size_t)_receiverCount SenderId:(int)audioSenderId SilenceSuppression:(int)silence
{
    audioGatewayInfo = audioGateway;
    videoGatewayInfo = videoGateway;
    receiverCount = _receiverCount;
    _senderId = audioSenderId;
    _silenceSuppression = silence;
    
    // configure audio session
    NSError* error;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionAllowBluetooth error:&error];
    [[AVAudioSession sharedInstance] setMode:AVAudioSessionModeVoiceChat error:nil];
    [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
    [[AVAudioSession sharedInstance] setInputGain:1.0 error:&error]; // ????
    [[AVAudioSession sharedInstance] setActive:YES error:&error];
}

- (void)mute:(BOOL)isMute
{
    vcCoreAudioInputMute(audioInput, isMute);
}

- (void)hangUp
{
    if (sender != NULL) {
        vcNetworkingSenderDestroy(sender); sender = NULL;
        vcEncoderDestroy(encoder); encoder = NULL;
        vcEncryptorDestroy(encryptor); encryptor = NULL;
        vcCoreAudioInputDestroy(audioInput); audioInput = NULL;
        vcNetworkingReceiverDestroy(receiver); receiver = NULL;
        for(int i=0; i < receiverCount; i++) {
            vcCoreAudioOutputDestroy(audioOutputs[i]);
            vcDecryptorDestroy(decryptors[i]);
            vcDecoderDestroy(decoders[i]);
        }
        receiverCount = 0;
        close(videoSocket);
    }
}

static void derive_key(const char *password, size_t password_size, uint8_t *key, size_t key_size) {
    uint8_t salt[] = {-106, -111, -100, -9, -25, -26, -21, 68, 6, 100, 45, -38, 109, -119, -76, -116};
    CCKeyDerivationPBKDF(kCCPBKDF2, password, password_size, salt, sizeof(salt), kCCPRFHmacAlgSHA256, 1<<20, key, key_size);
}

- (void)startVoIP
{
    const char *host = audioGatewayInfo.publicIP.UTF8String;
    const char *port = audioGatewayInfo.publicPort.UTF8String;
    
    // Setup sender
    uint8_t key[16];
    derive_key("foo", strlen("foo"), key, sizeof(key));
    
    encryptor = vcEncryptorCreate(key);
    encoder = vcEncoderCreate(_silenceSuppression);
    senderRingBuffer = vcRingBufferCreate();
    audioInput = vcCoreAudioInputCreate(senderRingBuffer, encryptor);
    sender = vcNetworkingSenderCreate(host, port, self.senderId, _silenceSuppression, senderRingBuffer, encryptor, encoder);
    
    NSLog(@"Receivercount: %zu", receiverCount);
    NSLog(@"SenderId is: %d", self.senderId);
    
    
    // TODO: These need to be freed
    decryptors = calloc(receiverCount, sizeof(vcDecryptor*));
    decoders = calloc(receiverCount, sizeof(vcDecoder*));
    receiverRingBuffers = calloc(receiverCount, sizeof(vcRingBuffer*));
    audioOutputs = calloc(receiverCount, sizeof(vcCoreAudioOutputContext*));
    vcCoreAudioInputStart(audioInput);
    
    for(int i=0; i < receiverCount; i++) {
        decryptors[i] = vcDecryptorCreate(key);
        // TODO don't hardcode this
        decoders[i] = vcDecoderCreate(5760);
        receiverRingBuffers[i] = vcRingBufferCreate();
        audioOutputs[i] = vcCoreAudioOutputCreate(receiverRingBuffers[i], decryptors[i], decoders[i]);
        vcCoreAudioOutputStart(audioOutputs[i]);
    }
    
    host = videoGatewayInfo.publicIP.UTF8String;
    port = videoGatewayInfo.publicPort.UTF8String;
    videoSocket = create_socket(host, port, 0);
    
    receiver = vcNetworkingReceiverCreateWithSocket(vcNetworkingSenderGetSocket(sender), videoSocket, receiverRingBuffers, receiverCount);
    
    vcNetworkingSenderStart(sender);
    vcNetworkingReceiverStart(receiver);
}

- (void)startVideo:(void (^)(NSData*))message
{
    dispatch_queue_t videoDispatchQueue = dispatch_queue_create("vcNetworkingVideoReceiver", DISPATCH_QUEUE_SERIAL);
    dispatch_async(videoDispatchQueue, ^{
        struct pollfd pollfds[] = {
            { videoSocket, POLLIN, 0 }
        };
        
        static uint8_t buffer[VC_VIDEO_BUFFER_SIZE];
        
        while (true) {
            int pret = poll(pollfds, 1, 16);
            if (pret == -1) {
                fprintf(stderr, "socket error\n");
                break;
            } else if (pret == 0) {
                continue;
            }
            ssize_t result = (int)read(videoSocket, buffer, VC_VIDEO_BUFFER_SIZE);
            
            if (result > 0) {
                int packetSize = *(int*)buffer;
                NSData *packet = [NSData dataWithBytes:buffer+sizeof(packetSize) length:result-sizeof(packetSize)];
                if (packetSize != packet.length) {
                    fprintf(stderr, "receive data %ld for packet %d\n", packet.length, packetSize);
                } else {
                    message(packet);
                }
            } else if (result == -1 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
                continue;
            } else {
                break;  // socket closed
            }
        }
        
        fprintf(stderr, "Stopping video receiver thread\n");
    });
    
}

- (void)sendVideoMessage:(CallMessage*)message {
    NSMutableData* data = [NSMutableData dataWithData: message.encrypt];
    int packetSize = (int)data.length;
    [data replaceBytesInRange:NSMakeRange(0, 0) withBytes:&packetSize length:sizeof(packetSize)];
    write(videoSocket, data.bytes, data.length);
}

@end