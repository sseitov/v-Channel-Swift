//
//  voipcodec.h
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#ifndef __VOIPCODEC_H_
#define __VOIPCODEC_H_

#include <stdbool.h>
#include <stddef.h>
#include <opus/opus.h>

typedef struct {
    OpusDecoder *opusDecoder;
    opus_int16 *outputBuffer;
    size_t outputBufferLength;
    size_t outputBufferSampleCount;
} vcDecoder;

typedef struct {
    OpusEncoder *opusEncoder;
    uint8_t outputBuffer[4096];
    size_t outputBufferLength;
} vcEncoder;

vcEncoder *vcEncoderCreate(int silenceSuppression);
bool vcEncode(vcEncoder *encoder, const int16_t *buffer, int32_t bufferSampleCount);
void vcEncoderDestroy(vcEncoder *encoder);

vcDecoder *vcDecoderCreate(uint32_t outputBufferSampleCount);
bool vcDecode(vcDecoder *decoder, const uint8_t *encodedBuffer, size_t encodedBufferLength);
void vcDecoderDestroy(vcDecoder *decoder);

#endif
