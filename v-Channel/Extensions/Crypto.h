//
//  Crypto.h
//
//  Created by Сергей Сейтов on 22.05.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Crypto : NSObject

+ (NSString*)md5HexDigest:(NSString*)input;
+ (NSString*)md5HexDigestData:(NSData *)input;
+ (NSString*)getBase64HMAC:(NSString*)data withKey:(NSString*)secret;

@end
