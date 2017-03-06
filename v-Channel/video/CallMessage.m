//
//  CallMessage.m
//  v-Channel
//
//  Created by Сергей Сейтов on 06.03.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import "CallMessage.h"
#import <MPMessagePack/MPMessagePack.h>

@implementation CallMessage

- (instancetype)initWithDictionary:(NSDictionary*)dictionary
{
    self = [super init];
    if (self) {
        self.messageType = [dictionary[@"messageType"] intValue];
    }
    return self;
}

- (NSDictionary*)pack
{
    return @{@"messageType" : [NSNumber numberWithInt:messageNone]};
}

- (NSData*)encrypt
{
    return [[self pack] mp_messagePack];
}

@end

@implementation CallVideoFrameMessage

- (instancetype)initWithDictionary:(NSDictionary*)dictionary
{
    self = [super initWithDictionary:dictionary];
    if (self) {
        _sps = dictionary[@"sps"];
        _pps = dictionary[@"pps"];
        _width = [dictionary[@"width"] intValue];
        _height = [dictionary[@"height"] intValue];
        _frame = dictionary[@"frame"];
    }
    return self;
}

- (NSDictionary*)pack {
    return @{@"messageType" : [NSNumber numberWithInt:messageFrame],
             @"sps" : _sps,
             @"pps" : _pps,
             @"width": [NSNumber numberWithInt:_width],
             @"height": [NSNumber numberWithInt:_height],
             @"frame": _frame};
}

@end

@implementation CallVideoStopMessage

- (NSDictionary*)pack
{
    return @{@"messageType" : [NSNumber numberWithInt:messageStop]};
}

@end
