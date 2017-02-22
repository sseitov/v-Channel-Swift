//
//  voipringbuffer.c
//  SimpleVOIP
//
//  Created by Сергей Сейтов on 01.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#include "voipringbuffer.h"

#include <stdio.h>

#include <libkern/OSAtomic.h>

vcRingBuffer *vcRingBufferCreate() {
    vcRingBuffer *buffer = calloc(1, sizeof(*buffer));

    pthread_mutexattr_t mutexattr;
    pthread_mutexattr_init(&mutexattr);
    pthread_mutexattr_settype(&mutexattr, PTHREAD_MUTEX_ERRORCHECK);
    pthread_mutex_init(&buffer->signalling_mutex, &mutexattr);
    pthread_cond_init(&buffer->signalling_cond, NULL);
    pthread_mutexattr_destroy(&mutexattr);
    return buffer;
}

void vcRingBufferDestroy(vcRingBuffer *buffer) {
    if (buffer != NULL) {
        pthread_cond_destroy(&buffer->signalling_cond);
        pthread_mutex_destroy(&buffer->signalling_mutex);
    }
    free(buffer);
}

void vcRingBufferClear(vcRingBuffer *buffer) {
    pthread_mutex_lock(&buffer->signalling_mutex);
    for (int i=0; i<VC_RINGBUFFER_LENGTH; i++) {
        buffer->data_size[i] = 0;
    }
    pthread_mutex_unlock(&buffer->signalling_mutex);
}

uint8_t *vcRingBufferProducerGetCurrent(vcRingBuffer *buffer) {
    return buffer->data[buffer->currentWrite];
}

void vcRingBufferProducerProduced(vcRingBuffer *buffer, size_t size) {
    pthread_mutex_lock(&buffer->signalling_mutex);
    buffer->data_size[buffer->currentWrite] = size;
    void *flag = &(buffer->flags[buffer->currentWrite]);

    buffer->currentWrite++;
    if(buffer->currentWrite >= VC_RINGBUFFER_LENGTH) {
        buffer->currentWrite = 0;
    }
    OSAtomicTestAndSetBarrier(VC_RINGBUFFER_FLAG_NEW_DATA, flag);
    
    pthread_mutex_unlock(&buffer->signalling_mutex);
    pthread_cond_signal(&buffer->signalling_cond);
    OSAtomicTestAndSetBarrier(VC_RINGBUFFER_FLAG_NEW_DATA, flag);
}

void vcRingBufferConsumerWait(vcRingBuffer *buffer) {
    pthread_mutex_lock(&buffer->signalling_mutex);
    if(vcRingBufferConsumerGetCurrent(buffer)) {
        pthread_mutex_unlock(&buffer->signalling_mutex);
        return;
    }
    pthread_cond_wait(&buffer->signalling_cond, &buffer->signalling_mutex);
    pthread_mutex_unlock(&buffer->signalling_mutex);
}

uint8_t *vcRingBufferConsumerGetCurrent(vcRingBuffer *buffer) {
    if(buffer->flags[buffer->currentRead]) {
        return buffer->data[buffer->currentRead];
    }
    return NULL;
}

// TODO: ConsumerGetCurrent should probably return the size and accept a uint8_t **
//       to get the buffers address
size_t vcRingBufferConsumerGetCurrentSize(vcRingBuffer *buffer) {
    if(buffer->flags[buffer->currentRead]) {
        return buffer->data_size[buffer->currentRead];
    }
    return 0;
}

void vcRingBufferConsumerConsumed(vcRingBuffer *buffer) {
    void *flag = &(buffer->flags[buffer->currentRead]);

    buffer->currentRead++;
    if(buffer->currentRead >= VC_RINGBUFFER_LENGTH) {
        buffer->currentRead = 0;
    }
    
    OSAtomicTestAndClearBarrier(VC_RINGBUFFER_FLAG_NEW_DATA, flag);
}
