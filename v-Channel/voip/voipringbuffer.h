//
//  voipringbuffer.h
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#ifndef __VC_RINGBUFFER_H_
#define __VC_RINGBUFFER_H_

#include <stdlib.h>
#include <pthread.h>

#define VC_RINGBUFFER_LENGTH 32
#define VC_RINGBUFFER_CELL_SIZE 8192
#define VC_RINGBUFFER_FLAG_NEW_DATA 1

typedef struct {
    uint8_t data[VC_RINGBUFFER_LENGTH][VC_RINGBUFFER_CELL_SIZE];
    size_t data_size[VC_RINGBUFFER_LENGTH];
    unsigned char flags[VC_RINGBUFFER_LENGTH];
    pthread_mutex_t signalling_mutex;
    pthread_cond_t signalling_cond;
    uint8_t currentRead, currentWrite;
} vcRingBuffer;

vcRingBuffer *vcRingBufferCreate();
void vcRingBufferDestroy(vcRingBuffer *buffer);
void vcRingBufferClear(vcRingBuffer *buffer);

uint8_t *vcRingBufferProducerGetCurrent(vcRingBuffer *buffer);
void vcRingBufferProducerProduced(vcRingBuffer *buffer, size_t size);

void vcRingBufferConsumerWait(vcRingBuffer *buffer);
uint8_t *vcRingBufferConsumerGetCurrent(vcRingBuffer *buffer);
size_t vcRingBufferConsumerGetCurrentSize(vcRingBuffer *buffer);
void vcRingBufferConsumerConsumed(vcRingBuffer *buffer);

#endif
