//
//  CallMessage.h
//  v-Channel
//
//  Created by Сергей Сейтов on 06.03.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import <Foundation/Foundation.h>

enum VideoMessageType {
    messageNone = 0,
    messageFrame,
    messageStop
};

@interface CallMessage : NSObject

@property (nonatomic) enum VideoMessageType messageType;

- (instancetype)initWithDictionary:(NSDictionary*)dictionary;
- (NSDictionary*)pack;
- (NSData*)encrypt;

@end

@interface CallVideoFrameMessage : CallMessage

@property (strong, nonatomic, readonly) NSData* sps;
@property (strong, nonatomic, readonly) NSData* pps;
@property (nonatomic, readonly) int width;
@property (nonatomic, readonly) int height;
@property (strong, nonatomic, readonly) NSData* frame;

@end

@interface CallVideoStopMessage : CallMessage

@end
