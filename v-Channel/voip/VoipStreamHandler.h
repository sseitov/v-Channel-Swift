//
//  VoipStreamHandler.h
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CallGatewayInfo.h"

#include "voipcodec.h"
#include "voipcrypto.h"
#include "voipcoreaudio.h"
#include "voipnetworking.h"
#include "voipringbuffer.h"

@interface VoipStreamHandler : NSObject {
    size_t receiverCount;
    
    vcRingBuffer *senderRingBuffer;
    vcRingBuffer **receiverRingBuffers;
    
    vcCoreAudioInputContext *audioInput;
    vcCoreAudioOutputContext **audioOutputs;
    
    vcEncryptor *encryptor;
    vcDecryptor **decryptors;
  
    vcEncoder *encoder;
    vcDecoder **decoders;
    
    vcNetworkingSenderContext *sender;
    vcNetworkingReceiverContext *receiver;
    
    CallGatewayInfo *gatewayInfo;
}

@property (assign, nonatomic, readonly) int senderId;
@property (assign, nonatomic, readonly) int silenceSuppression;

extern NSString *const NOTIFICATION_CALL_STREAM_ROUTING_UPDATE;

+ (VoipStreamHandler *)sharedInstance;

- (void)openWithGateway:(CallGatewayInfo*)_gatewayInfo ReceiverCount:(size_t)_receiverCount SenderId:(int)_senderId SilenceSuppression:(int)silence;

- (void)startVoIP;
- (void)waitForStart:(void (^)(void))start;
- (void)waitForFinish:(void (^)(void))finish;
- (void)hangUp;
- (void)mute:(BOOL)isMute;

- (void)enableLoudspeaker:(bool)speaker;
- (BOOL)isLoudSpeaker;

@end
