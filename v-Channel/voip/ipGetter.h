//
//  ipGetter.h
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#ifndef ipGetter_h
#define ipGetter_h

#include <stdbool.h>
#include <stdint.h>
#include <netdb.h>

typedef struct {
    int sock;
    char ipInfo[128];
    uint16_t port;
    struct sockaddr addr;
    socklen_t addrLen;
} ipGetter;

ipGetter *ipGetterCreate(const char *ipServer, const char *ipPort);
bool ipGetterCheck(ipGetter *getter);
bool ipGetterCheckBlocking(ipGetter *getter);
void ipGetterDestroy(ipGetter *getter);

#endif /* ipGetter_h */
