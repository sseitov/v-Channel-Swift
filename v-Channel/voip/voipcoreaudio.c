//
//  voipcoreaudio.c
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#include "voipcoreaudio.h"

#include <stdio.h>

static const AudioStreamBasicDescription FORMAT = {
    .mFormatID = kAudioFormatLinearPCM,
    .mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
	.mChannelsPerFrame = 1,
	.mSampleRate = 48000.0,
	.mBitsPerChannel = 16,
	.mFramesPerPacket = 1,
	.mBytesPerFrame = 2,
	.mBytesPerPacket = 2
};

static void CheckError(OSStatus error, const char *operation)
{
	if (error == noErr) return;
	
	char errorString[20];
	*(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
	if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
		errorString[0] = errorString[5] = '\'';
		errorString[6] = '\0';
	} else {
		snprintf(errorString, sizeof(errorString), "%d", (int)error);
	}
	
	fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
	
	exit(1);
}

#pragma mark - Audio input

// TODO: needs vcEncoder too
vcCoreAudioInputContext *vcCoreAudioInputCreate(vcRingBuffer *ringBuffer, vcEncryptor *encryptor)
{
    vcCoreAudioInputContext *context = calloc(1, sizeof(*context));
    context->isDone = false;
    context->encryptor = encryptor;
    context->ringBuffer = ringBuffer;
    return context;
}

static OSStatus vcCoreAudioInputCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    vcCoreAudioInputContext *context = inRefCon;

    if (inNumberFrames > VC_RINGBUFFER_CELL_SIZE / FORMAT.mBytesPerFrame ) {
        inNumberFrames = VC_RINGBUFFER_CELL_SIZE / FORMAT.mBytesPerFrame;
    }

    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mDataByteSize = VC_RINGBUFFER_CELL_SIZE;
    bufferList.mBuffers[0].mData = vcRingBufferProducerGetCurrent(context->ringBuffer);
    bufferList.mBuffers[0].mNumberChannels = FORMAT.mChannelsPerFrame;

    CheckError(AudioUnitRender(context->au, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList), "AudioUnitRender failed");

    vcRingBufferProducerProduced(context->ringBuffer, inNumberFrames * FORMAT.mBytesPerFrame);

    return noErr;
}

void vcCoreAudioInputStart(vcCoreAudioInputContext *context)
{
    AudioComponentDescription voiceUnitDesc;
    AUNode voiceNode;

    voiceUnitDesc.componentType = kAudioUnitType_Output;
    voiceUnitDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    voiceUnitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    voiceUnitDesc.componentFlags = 0;
    voiceUnitDesc.componentFlagsMask = 0;

    CheckError(NewAUGraph(&context->augraph), "NewAUGraph failed");
    CheckError(AUGraphAddNode(context->augraph, &voiceUnitDesc, &voiceNode), "AUGraphAddNode failed");
    CheckError(AUGraphOpen(context->augraph), "AUGraphOpen failed");
    CheckError(AUGraphNodeInfo(context->augraph, voiceNode, NULL, &context->au), "AUGraphNodeInfo failed");

    UInt32 enableInput        = 1;    // to enable input
    AudioUnitElement inputBus = 1;

    AudioUnitSetProperty(context->au, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, inputBus, &enableInput, sizeof(enableInput));

    UInt32 enableOutput        = 0;    // to disable output
    AudioUnitElement outputBus = 0;

    AudioUnitSetProperty(context->au, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, outputBus, &enableOutput, sizeof(enableOutput));

    CheckError(AudioUnitSetProperty(context->au, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, inputBus, &FORMAT, sizeof(FORMAT)), "AudioUnitSetProperty (StreamFormat) failed");
/*
    UInt32 uValue;
    uValue = 0;    // turn off AGC
    CheckError(AudioUnitSetProperty(context->au,
                                    kAUVoiceIOProperty_VoiceProcessingEnableAGC,
                                    kAudioUnitScope_Global,
                                    inputBus, &uValue, sizeof(uValue)), "AudioUnitSetProperty (VoiceProcessingEnableAGC) failed");
    
    uValue = 0;    // turn off the VP bypass, i.e. turn on VP
    CheckError(AudioUnitSetProperty(context->au,
                                    kAUVoiceIOProperty_BypassVoiceProcessing,
                                    kAudioUnitScope_Global,
                                    inputBus, &uValue, sizeof(uValue)), "AudioUnitSetProperty (BypassVoiceProcessing) failed");
 */   
    AURenderCallbackStruct callback;
    callback.inputProc = vcCoreAudioInputCallback;
    callback.inputProcRefCon = context;

    CheckError(AudioUnitSetProperty(context->au, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, inputBus, &callback, sizeof(callback)), "AudioUnitSetProperty (InputCallback) failed");

    CheckError(AUGraphInitialize(context->augraph), "AUGraphInitialize failed");

    CheckError(AUGraphStart(context->augraph), "AUGraphStart failed");
}

void vcCoreAudioInputDestroy(vcCoreAudioInputContext *context)
{
    if (context != NULL) {
        context->isDone = true;
        CheckError(AUGraphStop(context->augraph), "AUGraphStop failed");
        AUGraphUninitialize(context->augraph);
        AUGraphClose(context->augraph);
    }
    free(context);
}

void vcCoreAudioInputMute(vcCoreAudioInputContext *context, bool mute)
{
    if (mute) {
        CheckError(AUGraphStop(context->augraph), "AUGraphStop failed");
    } else {
        CheckError(AUGraphStart(context->augraph), "AUGraphStart failed");
    }
}

#pragma mark - Audio output

vcCoreAudioOutputContext *vcCoreAudioOutputCreate(vcRingBuffer *ringBuffer, vcDecryptor *decryptor, vcDecoder *decoder)
{
    vcCoreAudioOutputContext *context = calloc(1, sizeof(*context));
    context->isDone = false;
    context->decryptor = decryptor;
    context->decoder = decoder;
    context->ringBuffer = ringBuffer;
    context->pSamples = NULL;
    context->offset = 0;
    return context;
}

static void vcCoreAudioDecode(vcCoreAudioOutputContext* context)
{
    uint8_t *data = vcRingBufferConsumerGetCurrent(context->ringBuffer);
    size_t dataSize = vcRingBufferConsumerGetCurrentSize(context->ringBuffer);
    
    vcRingBufferConsumerConsumed(context->ringBuffer);
    if(data && (dataSize >= 20)) {
        vcDecryptorDecrypt(context->decryptor, data);
        vcDecode(context->decoder, context->decryptor->decrypted, context->decryptor->decryptedLength);
    } else {
        // Opus can try to 'predict' data
        vcDecode(context->decoder, NULL, 0);
    }
    context->pSamples = (uint8_t*)context->decoder->outputBuffer;
    context->offset = 0;
}

static void vcCoreFillBuffer(vcCoreAudioOutputContext* context, AudioBuffer* buffer)
{
    int restBytes = (int)context->decoder->outputBufferLength*2 - context->offset;
    int bufferSize = buffer->mDataByteSize;
    uint8_t *pData = buffer->mData;
    if (restBytes >= bufferSize) {
        memcpy(pData, context->pSamples+context->offset, bufferSize);
        context->offset += bufferSize;
    } else {
        memcpy(pData, context->pSamples+context->offset, restBytes);
        bufferSize -= restBytes;
        vcCoreAudioDecode(context);
        memcpy(pData+restBytes, context->pSamples, bufferSize);
        context->offset = bufferSize;
    }
}

static OSStatus vcCoreAudioOutputCallback(void *inRefCon,
                                          AudioUnitRenderActionFlags *ioActionFlags,
                                          const AudioTimeStamp *inTimeStamp,
                                          UInt32 inBusNumber,
                                          UInt32 inNumberFrames,
                                          AudioBufferList *ioData)
{
    vcCoreAudioOutputContext *context = inRefCon;
    if (!context->pSamples) {
        vcCoreAudioDecode(context);
    }
    vcCoreFillBuffer(context, ioData->mBuffers);
    return noErr;
}

void vcCoreAudioOutputStart(vcCoreAudioOutputContext *context)
{
    CheckError(NewAUGraph(&context->augraph), "NewAUGraph failed");
    
    // output component
    AudioComponentDescription output_desc;
    output_desc.componentType = kAudioUnitType_Output;
    output_desc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    output_desc.componentFlags = 0;
    output_desc.componentFlagsMask = 0;
    output_desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    // Get component
    AUNode outputNode;
    CheckError(AUGraphAddNode(context->augraph, &output_desc, &outputNode), "AUGraphAddNode failed");

    // Open the graph and get link to unit
    CheckError(AUGraphOpen(context->augraph), "AUGraphOpen failed");
    AudioUnit outputUnit;
    CheckError(AUGraphNodeInfo(context->augraph, outputNode, NULL, &outputUnit), "AUGraphNodeInfo failed");
    
    // Enable IO for playback
    UInt32 flag = 1;
    CheckError(AudioUnitSetProperty(outputUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Output,
                                  0,
                                  &flag,
                                  sizeof(flag)), "AudioUnitSetProperty failed");
    
    // Apply format
    CheckError(AudioUnitSetProperty(outputUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  1,
                                  &FORMAT,
                                  sizeof(FORMAT)), "AudioUnitSetProperty kAudioUnitProperty_StreamFormat for input failed");
    CheckError(AudioUnitSetProperty(outputUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &FORMAT,
                                  sizeof(FORMAT)), "AudioUnitSetProperty kAudioUnitProperty_StreamFormat for output failed");
    
    // Set output callback
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = vcCoreAudioOutputCallback;
    callbackStruct.inputProcRefCon = context;
    CheckError(AudioUnitSetProperty(outputUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  0,
                                  &callbackStruct,
                                  sizeof(callbackStruct)), "AudioUnitSetProperty kAudioUnitProperty_SetRenderCallback failed");
    
    // Initialise & start
    CheckError(AUGraphInitialize(context->augraph), "AUGraphInitialize failed");
    CheckError(AUGraphStart(context->augraph), "AUGraphStart failed");
}

void vcCoreAudioOutputMute(vcCoreAudioOutputContext *context, bool mute)
{
    if (mute) {
        CheckError(AUGraphStop(context->augraph), "AUGraphStop failed");
    } else {
        CheckError(AUGraphStart(context->augraph), "AUGraphStart failed");
    }
}

void vcCoreAudioOutputDestroy(vcCoreAudioOutputContext *context)
{
    if (context != NULL) {
        context->isDone = true;
        CheckError(AUGraphStop(context->augraph), "AUGraphStop failed");
        AUGraphUninitialize(context->augraph);
        AUGraphClose(context->augraph);
    }
    free(context);
}
