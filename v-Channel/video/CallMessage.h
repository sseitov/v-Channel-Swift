//
//  CallMessage.h
//  v-Channel
//
//  Created by Сергей Сейтов on 06.03.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CallMessage : NSObject

@property (strong, nonatomic) NSString* messageType;

- (NSDictionary*)pack;
- (NSData*)encrypt;

@end

@interface CallVideoStartMessage : CallMessage

- (instancetype)initWithDictionary:(NSDictionary*)dictionary;

@property (strong, nonatomic) NSData* sps;
@property (strong, nonatomic) NSData* pps;
@property (nonatomic) int width;
@property (nonatomic) int height;

@end

@interface CallVideoFrameMessage : CallMessage

- (instancetype)initWithDictionary:(NSDictionary*)dictionary;

@property (strong, nonatomic) NSData* frame;

@end

@interface CallVideoAcceptMessage : CallMessage
@end

@interface CallVideoStopMessage : CallMessage
@end
