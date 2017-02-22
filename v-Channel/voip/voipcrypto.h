//
//  voipcrypto.h
//  v-Channel
//
//  Created by Сергей Сейтов on 16.02.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#ifndef __VOIPCRYPTO_H_
#define __VOIPCRYPTO_H_

#include <stdlib.h>
#include <stdbool.h>
#include <stddef.h>

typedef struct {
    uint8_t key[16];
    uint8_t decrypted[4096]; // TODO: should this really be fixed size?
    size_t decryptedLength;
} vcDecryptor;

typedef struct {
    uint8_t key[16];
    uint8_t encrypted[4096]; // TODO: should this really be fixed size?
    size_t encryptedLength;
} vcEncryptor;

vcDecryptor *vcDecryptorCreate(const uint8_t key[16]);
bool vcDecryptorDecrypt(vcDecryptor *decryptor, const uint8_t *dataFrame);
void vcDecryptorDestroy(vcDecryptor *decryptor);

vcEncryptor *vcEncryptorCreate(const uint8_t key[16]);
bool vcEncryptorEncrypt(vcEncryptor *encryptor, const uint8_t *data, size_t dataLength, const void *iv);
void vcEncryptorDestroy(vcEncryptor *encryptor);

#endif
