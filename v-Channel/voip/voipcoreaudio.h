//
//  voipcoreaudio.h
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#ifndef __VOIPCOREAUDIO_H_
#define __VOIPCOREAUDIO_H_

#include <AudioToolbox/AudioToolbox.h>

#include "voipringbuffer.h"
#include "voipcrypto.h"
#include "voipcodec.h"

#define kNumberRecordBuffers 3
#define kNumberPlaybackBuffers 3

#define INPUT_BUFFER_SIZE 1920
#define OUTPUT_BUFFER_SAMPLE_COUNT 5760

typedef struct {
    AUGraph augraph;
    vcRingBuffer *ringBuffer;
    vcDecoder *decoder;
    vcDecryptor *decryptor;
    uint8_t *pSamples;
    int offset;
    bool isDone;
} vcCoreAudioOutputContext;

typedef struct {
    AudioUnit au;
    AUGraph augraph;
    vcRingBuffer *ringBuffer;
    vcEncryptor *encryptor;
    bool isDone;
    
} vcCoreAudioInputContext;

vcCoreAudioInputContext *vcCoreAudioInputCreate(vcRingBuffer *ringBuffer, vcEncryptor *encryptor);
void vcCoreAudioInputStart(vcCoreAudioInputContext *context);
void vcCoreAudioInputDestroy(vcCoreAudioInputContext *context);
void vcCoreAudioInputMute(vcCoreAudioInputContext *context, bool mute);

vcCoreAudioOutputContext *vcCoreAudioOutputCreate(vcRingBuffer *ringBuffer, vcDecryptor *decryptor, vcDecoder *decoder);
void vcCoreAudioOutputStart(vcCoreAudioOutputContext *context);
void vcCoreAudioOutputDestroy(vcCoreAudioOutputContext *context);
void vcCoreAudioOutputMute(vcCoreAudioOutputContext *context, bool mute);

#endif
