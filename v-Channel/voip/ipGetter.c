//
//  ipGetter.c
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#include "ipGetter.h"

#include <stdio.h>
#include <stdlib.h>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <poll.h>
#include <string.h>
#include <stdbool.h>
#include <unistd.h>
#include <fcntl.h>

ipGetter *ipGetterCreate(const char *ipServer, const char *ipPort) {
    fprintf(stderr, "Creating IPGetter\n");
    struct addrinfo hints, *dstInfo = NULL, *r;
    ipGetter *ret = calloc(1, sizeof(*ret));
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_DGRAM;
    hints.ai_protocol = 0;
    hints.ai_flags = 0;
    
    int error = getaddrinfo(ipServer, ipPort, &hints, &dstInfo);
    
    if (error != 0) {
        fprintf(stderr, "getaddrinfo failed: %s\n", gai_strerror(error));
        goto error;
    }
    
    for (r = dstInfo; r; r = r->ai_next) {
        ret->sock = socket(r->ai_family, r->ai_socktype, r->ai_protocol);
        
        if(ret->sock == -1) {
            continue;
        }
        
        char *message = "GIVE_IP";
        
        ret->addr = *r->ai_addr;
        ret->addrLen = r->ai_addrlen;
        
        if (sendto(ret->sock, message, strlen(message), 0, r->ai_addr, r->ai_addrlen) != -1) {
            struct sockaddr sa;
            socklen_t saLen = sizeof(sa);
            if (getsockname(ret->sock, (struct sockaddr*)&sa, &saLen) == -1) {
                perror("getsockname");
                goto nextai;
            }
            switch (sa.sa_family) {
                case AF_INET:
                    ret->port = ntohs(((struct sockaddr_in*)&sa)->sin_port);
                    break;
                case AF_INET6:
                    ret->port = ntohs(((struct sockaddr_in6*)&sa)->sin6_port);
                    break;
                default:
                    goto nextai;
            }
            break;
        }
    nextai:
        close(ret->sock);
    }
    
    if (!r) {
        fprintf(stderr, "Failed to set socket.\n");
        goto error;
    }
    
    fcntl(ret->sock, F_SETFL, O_NONBLOCK);
    
    goto success;
error:
    free(ret);
    ret = NULL;
success:
    if (dstInfo != NULL) {
        freeaddrinfo(dstInfo);
    }
    
    return ret;
}

static bool ipGetterDoCheck(ipGetter *getter, int timeout) {
    if (getter == NULL) {
        return false;
    }
    
    fprintf(stderr, "IPGetter check\n");
    struct pollfd pollfds[] = {
        { getter->sock, POLLIN, 0 }
    };
    int pret = poll(pollfds, 1, timeout);
    if (pret == -1) {
        // TODO: This should close the IPGetter I guess?
        fprintf(stderr, "pret is -1\n");
        return false;
    } else if(pret == 0) {
        fprintf(stderr, "pret is 0\n");
        char *message = "GIVE_IP";
        
        if (sendto(getter->sock, message, strlen(message), 0, &getter->addr, getter->addrLen) != -1) {
            fprintf(stderr, "Requested again\n");
        } else {
            fprintf(stderr, "Failed to request\n");
        }
        
        return false;
    }
    
    ssize_t result = read(getter->sock, getter->ipInfo, sizeof(getter->ipInfo));
    
    if (result == -1) {
        perror("read");
        return false;
    }
    else if (result < (ssize_t)sizeof(getter->ipInfo)) {
        getter->ipInfo[result] = 0;
    }
    else {
        getter->ipInfo[sizeof(getter->ipInfo) - 1] = 0;
    }
    
    if (result > 0) {
        fprintf(stderr, "IP Getter got %ld bytes\n", result);
        close(getter->sock);
        return true;
    } else {
        // TODO: This should do error checking (errno must be EAGAIN etc)
        return false;
    }
}

bool ipGetterCheck(ipGetter *getter) {
    return ipGetterDoCheck(getter, 0);
}

bool ipGetterCheckBlocking(ipGetter *getter) {
    return ipGetterDoCheck(getter, -1);
}

void ipGetterDestroy(ipGetter *getter) {
    if (getter != NULL) {
        close(getter->sock);
    }
    free(getter);
}
