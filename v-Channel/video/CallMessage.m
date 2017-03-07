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

- (NSDictionary*)pack
{
    return nil;
}

- (NSData*)encrypt
{
    return [[self pack] mp_messagePack];
}

@end

@implementation CallVideoStartMessage

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.messageType = @"start";
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary*)dictionary
{
    self = [super init];
    if (self) {
        self.messageType = dictionary[@"type"];
        _sps = dictionary[@"sps"];
        _pps = dictionary[@"pps"];
        _width = [dictionary[@"width"] intValue];
        _height = [dictionary[@"height"] intValue];
    }
    return self;
}

- (NSDictionary*)pack {
    return @{@"type" : @"start",
             @"sps" : _sps,
             @"pps" : _pps,
             @"width": [NSNumber numberWithInt:_width],
             @"height": [NSNumber numberWithInt:_height]};
}

@end

@implementation CallVideoFrameMessage

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.messageType = @"frame";
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary*)dictionary
{
    self = [super init];
    if (self) {
        self.messageType = dictionary[@"type"];
        _frame = dictionary[@"frame"];
    }
    return self;
}

- (NSDictionary*)pack {
    return @{@"type" : @"frame", @"frame": _frame};
}

@end

@implementation CallVideoAcceptMessage

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.messageType = @"accept";
    }
    return self;
}

- (NSDictionary*)pack
{
    return @{@"type" : @"accept"};
}

@end

@implementation CallVideoStopMessage

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.messageType = @"stop";
    }
    return self;
}

- (NSDictionary*)pack
{
    return @{@"type" : @"stop"};
}

@end
