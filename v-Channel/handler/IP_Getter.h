//
//  IP_Getter.h
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "ipGetter.h"

@interface IP_Getter : NSObject

@property (assign, nonatomic) ipGetter* getter;

- (instancetype)init:(NSString*)server port:(NSString*)port;
- (bool)check;
- (bool)checkBlocking;

@end
