//
//  voipcodec.c
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#include "voipcodec.h"

#include <stdio.h>
#include <stdlib.h>
#include <limits.h>

// TODO: Does this need to be dynamic?
#define SAMPLE_RATE 48000.0
#define CHANNELS_PER_FRAME 1


vcEncoder *vcEncoderCreate(int silenceSuppression) {
    vcEncoder *encoder = calloc(1, sizeof(vcEncoder));
    int error = 0;
    encoder->opusEncoder = opus_encoder_create(SAMPLE_RATE, CHANNELS_PER_FRAME, OPUS_APPLICATION_VOIP, &error);
	if (error != OPUS_OK) {
		fprintf(stderr, "Failed to create a OPUS encoder (%d)\n", error);
		goto error;
	}
    goto success;
error:
    free(encoder);
    encoder = NULL;
success:
    opus_encoder_ctl(encoder->opusEncoder, OPUS_SET_LSB_DEPTH(silenceSuppression));
    return encoder;
}

bool vcEncode(vcEncoder *encoder, const int16_t *buffer, int32_t bufferSampleCount) {
    
    encoder->outputBufferLength = 0;
    
//    int silence = 0;
//    opus_encoder_ctl(encoder->opusEncoder, OPUS_GET_LSB_DEPTH(&silence));
    
    int32_t length = opus_encode(encoder->opusEncoder, buffer, bufferSampleCount, encoder->outputBuffer, sizeof(encoder->outputBuffer));

    if (length < 0) {
//        fprintf(stderr, "Failed to encode data (%d)\n", length);
        return false;
    } else {
//        fprintf(stderr, "Encode data (%d), silence (%d)\n", length, silence);
        encoder->outputBufferLength = length;
        return true;
    }
}

void vcEncoderDestroy(vcEncoder *encoder) {
    if (encoder != NULL) {
        opus_encoder_destroy(encoder->opusEncoder);
    }
    free(encoder);
}

/*
 * Creates a decoder that can then be used with vcDecoder....
 *
 * returns NULL on failure and a newly allocated vcDecoder on success.
 */
vcDecoder *vcDecoderCreate(uint32_t outputBufferSampleCount) {
    vcDecoder *decoder = calloc(1, sizeof(vcDecoder));
    int error = 0;
    decoder->opusDecoder = opus_decoder_create((int)SAMPLE_RATE, CHANNELS_PER_FRAME, &error);
    if(error != OPUS_OK) {
        free(decoder);
        fprintf(stderr, "Failed to create OPUS decoder (%d)\n", error);
        return NULL;
    }
    
    decoder->outputBuffer = calloc(outputBufferSampleCount, sizeof(*decoder->outputBuffer));
    decoder->outputBufferLength = 0;
    decoder->outputBufferSampleCount = outputBufferSampleCount;
    return decoder;
}

bool vcDecode(vcDecoder *decoder, const uint8_t *encodedBuffer, size_t encodedBufferLength) {
    if(encodedBufferLength && encodedBufferLength > (size_t)INT_MAX) {
        fprintf(stderr, "encoder_buffer_length is higher than what opus_decode can handle.\n");
        return false;
    }
    
    int decodedSize = opus_decode(decoder->opusDecoder, encodedBuffer, (int)encodedBufferLength, decoder->outputBuffer, (int)decoder->outputBufferSampleCount, 0);
    
    if(decodedSize < 0) {
        fprintf(stderr, "Failed to decode samples (%d)\n", decodedSize);
        decoder->outputBufferLength = 0;
        return false;
    }
    
    decoder->outputBufferLength = decodedSize;
    
    return true;
}

void vcDecoderDestroy(vcDecoder *decoder) {
    if (decoder != NULL) {
        opus_decoder_destroy(decoder->opusDecoder);
        free(decoder->outputBuffer);
    }
    free(decoder);
}
