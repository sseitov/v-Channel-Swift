//
//  IP_Getter.m
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import "IP_Getter.h"

@implementation IP_Getter

- (instancetype)init:(NSString*)server port:(NSString*)port {
    self = [super init];
    _getter = ipGetterCreate(server.UTF8String, port.UTF8String);
    return self;
}

- (void)dealloc {
    ipGetterDestroy(_getter);
}

- (bool)check {
    return ipGetterCheck(_getter);
}

- (bool)checkBlocking {
    return ipGetterCheckBlocking(_getter);
}

@end
