//
//  voipcrypto.c
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#include "voipcrypto.h"

#include <stdio.h>
#include <arpa/inet.h>

#include <CommonCrypto/CommonCrypto.h>
#include <Security/Security.h>

vcDecryptor *vcDecryptorCreate(const uint8_t key[16]) {
    vcDecryptor *decryptor = calloc(1, sizeof(vcDecryptor));
    for(int i=0; i < 16; i++) {
        decryptor->key[i] = key[i];
    }
    
    decryptor->decryptedLength = 0;
    
    return decryptor;
}

bool vcDecryptorDecrypt(vcDecryptor *decryptor, const uint8_t *dataFrame) {
    uint32_t encryptedDataLength = ntohl(*(uint32_t*)dataFrame) - 16; // remove IV size
    const void *iv = dataFrame + 4;
    const uint8_t *encryptedData = dataFrame + 20; // 4B length, 16B IV
    CCCryptorRef decryptorRef;
    // TODO: Should the CryptoRef be in vcDecryptor?
    CCCryptorStatus status = CCCryptorCreateWithMode(kCCDecrypt,
                                                     kCCModeCTR,
                                                     kCCAlgorithmAES,
                                                     ccPKCS7Padding,
                                                     iv,
                                                     decryptor->key,
                                                     sizeof(decryptor->key),
                                                     NULL, 0, 0, kCCModeOptionCTR_BE,
                                                     &decryptorRef);
    if(status != kCCSuccess) {
        fprintf(stderr, "Failed to create decryptor (%d)\n", status);
        return false;
    }
    
    size_t alreadyDecrypted = 0;
    
    status = CCCryptorUpdate(decryptorRef,
                             encryptedData,
                             encryptedDataLength,
                             decryptor->decrypted,
                             sizeof(decryptor->decrypted),
                             &alreadyDecrypted);
    
    if(status != kCCSuccess) {
        fprintf(stderr, "Failed to decrypt data (%d)\n", status);
        return false;
    }
    
    status = CCCryptorFinal(decryptorRef,
                            decryptor->decrypted + alreadyDecrypted,
                            sizeof(decryptor->decrypted) - alreadyDecrypted,
                            &decryptor->decryptedLength);
    
    if(status != kCCSuccess) {
        fprintf(stderr, "Failed to finish decryption (%d)\n", status);
        return false;
    }
    
    CCCryptorRelease(decryptorRef);
    
    decryptor->decryptedLength += alreadyDecrypted;
    
    return true;
}

void vcDecryptorDestroy(vcDecryptor *decryptor) {
    if (decryptor != NULL) {
        memset(decryptor->key, 0, sizeof(decryptor->key));
    }
    free(decryptor);
}

vcEncryptor *vcEncryptorCreate(const uint8_t key[16]) {
    vcEncryptor *encryptor = calloc(1, sizeof(vcEncryptor));
    
    for(int i=0; i < 16; i++) {
        encryptor->key[i] = key[i];
    }
    
    encryptor->encryptedLength = 0;
    
    return encryptor;
}

bool vcEncryptorEncrypt(vcEncryptor *encryptor, const uint8_t *data, size_t dataLength, const void *iv) {
    uint32_t *frameLength = (uint32_t*)encryptor->encrypted;

    // 4 bytes are the frame length
    void *frameIV = encryptor->encrypted + 4;
    // 4 byte length + 16 byte IV
    uint8_t *frameEncryptedBuffer = encryptor->encrypted + 20;

    size_t encryptedBufferSize = sizeof(encryptor->encrypted) - 20;
    
    // TODO: IV is always 16 bytes.. shouldn't we ask for an uint8_t iv[16]?
    memcpy(frameIV, iv, 16);
    
    CCCryptorRef encryptorRef;
    CCCryptorStatus status = CCCryptorCreateWithMode(kCCEncrypt,
                                                     kCCModeCTR,
                                                     kCCAlgorithmAES,
                                                     ccPKCS7Padding,
                                                     frameIV,
                                                     encryptor->key,
                                                     sizeof(encryptor->key),
                                                     NULL, 0, 0, kCCModeOptionCTR_BE,
                                                     &encryptorRef);
    if(status != kCCSuccess) {
        fprintf(stderr, "Failed to create encryptor (%d)\n", status);
        return false;
    }
    
    size_t alreadyEncrypted = 0;
    size_t justEncrypted = 0;
    
    status = CCCryptorUpdate(encryptorRef,
                             data,
                             dataLength,
                             frameEncryptedBuffer,
                             encryptedBufferSize,
                             &justEncrypted);
    
    if(status != kCCSuccess) {
        fprintf(stderr, "Failed to encrypted data (%d)\n", status);
        return false;
    }
    
    alreadyEncrypted += justEncrypted;
    justEncrypted = 0;
    status = CCCryptorFinal(encryptorRef,
                            frameEncryptedBuffer + alreadyEncrypted,
                            encryptedBufferSize - alreadyEncrypted,
                            &justEncrypted);
    
    if(status != kCCSuccess) {
        fprintf(stderr, "Failed to finish encryption (%d)\n", status);
        return false;
    }
    
    alreadyEncrypted += justEncrypted;
    
    CCCryptorRelease(encryptorRef);
    
    encryptor->encryptedLength = alreadyEncrypted + 20;
    
    *frameLength = htonl((uint32_t)encryptor->encryptedLength-4);
    
    return true;
}

void vcEncryptorDestroy(vcEncryptor *encryptor) {
    if (encryptor != NULL) {
        memset(encryptor->key, 0, sizeof(encryptor->key));
    }
    free(encryptor);
}
