//
//  CallGatewayInfo.h
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IP_Getter.h"

@interface CallGatewayInfo : NSObject

@property (nonatomic, retain) NSString *publicIP;
@property (nonatomic, retain) NSString *publicPort;

- (instancetype)initWithIPGetter:(IP_Getter*)ipGetter;
- (instancetype)initWithIP:(NSString*)ip Port:(NSString*)port;

@end
