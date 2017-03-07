//
//  CallGatewayInfo.m
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import "CallGatewayInfo.h"

@implementation CallGatewayInfo

- (instancetype)initWithIPGetter:(IP_Getter*)ipGetter {
    self = [super init];
    if(self) {
        NSData *dataB64 = [NSData dataWithBytes:ipGetter.getter->ipInfo length:strlen(ipGetter.getter->ipInfo)];
        NSData *data = [[NSData alloc] initWithBase64EncodedData:dataB64 options:0];
        NSDictionary *ip  = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        
        self.publicIP = ip[@"PublicIP"];
        self.publicPort = ip[@"PublicPort"];
    }
    return self;
}

- (instancetype)initWithIP:(NSString*)ip Port:(NSString*)port {
    self = [super init];
    if(self) {
        self.publicIP = ip;
        self.publicPort = port;
    }
    return self;
}

@end
