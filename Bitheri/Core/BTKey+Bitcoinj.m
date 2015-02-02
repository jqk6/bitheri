//
//  BTKey+Bitcoinj.m
//  bitheri
//
//  Copyright 2014 http://Bither.net
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "BTKey+Bitcoinj.h"
#import "NSString+Base58.h"
#import "NSMutableData+Bitcoin.h"
#import "BTQRCodeUtil.h"
#import "BTUtils.h"
#import "BTEncryptData.h"

@implementation BTKey (Bitcoinj)

+ (instancetype)keyWithBitcoinj:(NSString *)key andPassphrase:(NSString *)passphrase; {
    return [[self alloc] initKeyWithBitcoinj:key andPassphrase:passphrase];
}

- (instancetype)initKeyWithBitcoinj:(NSString *)key andPassphrase:(NSString *)passphrase; {
    NSArray *array = [BTQRCodeUtil splitQRCode:key];
    BOOL compressed = YES;
    BOOL isXRandom = NO;
    NSData *data = [array[2] hexToData];
    NSMutableData *salt = [NSMutableData new];
    if (data.length == 9) {
        uint8_t *bytes = (uint8_t *) data.bytes;
        uint8_t flag = bytes[0];
        compressed = (flag & IS_COMPRESSED_FLAG) == IS_COMPRESSED_FLAG;
        isXRandom = (flag & IS_FROMXRANDOM_FLAG) == IS_FROMXRANDOM_FLAG;
        for (int i = 1; i < data.length; i++) {
            [salt appendUInt8:bytes[i]];
        }
    } else {
        [salt appendData:data];
    }
    NSData *secret = [BTEncryptData decryptFrom:[array[0] hexToData] andPassphrase:passphrase andSalt:salt andIV:[array[1] hexToData]];
    if (secret == nil)
        return nil;
    self = [self initWithSecret:secret compressed:compressed];
    self.isFromXRandom = isXRandom;
    if (!self) return nil;
    return self;
}

- (NSString *)bitcoinjKeyWithPassphrase:(NSString *)passphrase andSalt:(NSData *)salt andIV:(NSData *)iv flag:(uint8_t)flag {
    NSData *secret = [[self.privateKey base58checkToData] subdataWithRange:NSMakeRange(1, 32)];
    NSMutableData *data = [NSMutableData new];
    [data appendUInt8:flag];
    [data appendData:salt];
    NSArray *array = @[[NSString hexWithData:[BTEncryptData encryptSecret:secret withPassphrase:passphrase andSalt:salt andIV:iv]], [NSString hexWithData:iv], [NSString hexWithData:data]];
    NSString *encryptString = [BTQRCodeUtil joinedQRCode:array];
    BTKey *key = [self initKeyWithBitcoinj:encryptString andPassphrase:passphrase];
    if (key && [BTUtils compareString:self.address compare:key.address]) {
        return encryptString;
    } else {
        return nil;
    }
}


//// encrypts receiver with passphrase and returns Bitcoinj key
//- (NSData *)encryptSecret:(NSData *)secret withPassphrase:(NSString *)passphrase andSalt:(NSData *)salt andIV:(NSData *) iv
//{
//    NSData *password = [passphrase dataUsingEncoding:NSUTF16BigEndianStringEncoding];
//    NSData *derived = scrypt(password, salt, BITCOINJ_SCRYPT_N, BITCOINJ_SCRYPT_R, BITCOINJ_SCRYPT_P, 32);
//
//    CCOperation operation = kCCEncrypt;
//    NSData *result = [self doCipher:secret iv:iv key:derived operation:operation];
//
//    return  result;
//}
//
//- (NSData *)decryptFrom:(NSData *)encrypted andPassphrase:(NSString *)passphrase andSalt:(NSData *)salt andIV:(NSData *) iv;{
//    NSData *password = [passphrase dataUsingEncoding:NSUTF16BigEndianStringEncoding];
//    NSData *derived = scrypt(password, salt, BITCOINJ_SCRYPT_N, BITCOINJ_SCRYPT_R, BITCOINJ_SCRYPT_P, 32);
//
//    CCOperation operation = kCCDecrypt;
//    NSData *result = [self doCipher:encrypted iv:iv key:derived operation:operation];
//    return result;
//}
//
//- (NSData *)doCipher:(NSData *)data iv:(NSData *)iv key:(NSData *)key operation:(CCOperation)operation {
//    if (operation == kCCDecrypt && ![self checkCipher:data iv:iv key:key operation:operation])
//        return nil;
//
//    NSMutableData *buffer;
//    size_t len, actualLen = 0, remainLen;
//    CCCryptorRef cryptor;
//    if (CCCryptorCreateWithMode(operation, kCCModeCBC, kCCAlgorithmAES, kCCOptionPKCS7Padding, iv.bytes
//            , key.bytes, kCCKeySizeAES256, NULL, 0, 0, kCCModeOptionCTR_BE, &cryptor) == kCCSuccess){
//        remainLen = CCCryptorGetOutputLength(cryptor, data.length, true);
//        buffer = [NSMutableData secureDataWithLength:(NSUInteger) remainLen];
//
//        if (CCCryptorUpdate(cryptor, data.bytes, data.length, buffer.mutableBytes, buffer.length, &len) == kCCSuccess){
//            remainLen -= len;
//            actualLen += len;
//        }
//
//        if (CCCryptorFinal(cryptor, buffer.mutableBytes + len, remainLen, &len) == kCCSuccess){
//            actualLen += len;
//            CCCryptorRelease(cryptor);
//            cryptor = NULL;
//        }
//    }
//    NSData *result = [buffer subdataWithRange:NSMakeRange(0, actualLen)];
//    return result;
//}
//
//- (BOOL)checkCipher:(NSData *)data iv:(NSData *)iv key:(NSData *)key operation:(CCOperation)operation {
//    NSMutableData *buffer;
//    size_t len, actualLen = 0, remainLen;
//    CCCryptorRef cryptor;
//    if (CCCryptorCreateWithMode(operation, kCCModeCBC, kCCAlgorithmAES, kCCOptionECBMode, iv.bytes
//            , key.bytes, kCCKeySizeAES256, NULL, 0, 0, kCCModeOptionCTR_BE, &cryptor) == kCCSuccess){
//        remainLen = CCCryptorGetOutputLength(cryptor, data.length, true);
//        buffer = [NSMutableData secureDataWithLength:(NSUInteger) remainLen];
//
//        if (CCCryptorUpdate(cryptor, data.bytes, data.length, buffer.mutableBytes, buffer.length, &len) == kCCSuccess){
//            remainLen -= len;
//            actualLen += len;
//        }
//
//        if (CCCryptorFinal(cryptor, buffer.mutableBytes + len, remainLen, &len) == kCCSuccess){
//            actualLen += len;
//            CCCryptorRelease(cryptor);
//            cryptor = NULL;
//        }
//    }
//    if (buffer.length == 48) {
//        for (NSUInteger i = 32; i < 48; i++){
//            if ([buffer UInt8AtOffset:i] != 0x10)
//                return NO;
//        }
//        return YES;
//    } else {
//        return NO;
//    }
//}
+ (NSString *)reEncryptPrivKeyWithOldPassphrase:(NSString *)encryptPrivKey oldPassphrase:(NSString *)oldPassphrase andNewPassphrase:(NSString *)newPassphrase {
    BTKey *key = [BTKey keyWithBitcoinj:encryptPrivKey andPassphrase:oldPassphrase];
    NSData *data = [BTKey saltWithBitcoinj:encryptPrivKey];
    NSMutableData *salt = [NSMutableData new];
    uint8_t flag = 0;
    if (data.length == 9) {
        uint8_t *bytes = (uint8_t *) data.bytes;
        flag = bytes[0];
        for (int i = 1; i < data.length; i++) {
            [salt appendUInt8:bytes[i]];
        }
    } else {
        flag = [key getKeyFlag];
        [salt appendData:data];
    }
    NSData *iv = [BTKey ivWithBitcoinj:encryptPrivKey];
    if (key) {
        return [key bitcoinjKeyWithPassphrase:newPassphrase andSalt:salt andIV:iv flag:flag];
    } else {
        return nil;
    }
}

+ (NSData *)saltWithBitcoinj:(NSString *)key; {
    NSArray *array = [BTQRCodeUtil splitQRCode:key];
    if ([array count] == 3)
        return [array[2] hexToData];
    else
        return nil;
}

+ (NSData *)ivWithBitcoinj:(NSString *)key; {
    NSArray *array = [BTQRCodeUtil splitQRCode:key];
    if ([array count] == 3)
        return [array[1] hexToData];
    else
        return nil;
}

+ (BOOL)isXRandom:(NSString *)encryptPrivKey; {
    NSArray *array = [BTQRCodeUtil splitQRCode:encryptPrivKey];
    NSData *data = [array[2] hexToData];
    BOOL isXRandom = NO;
    if (data.length == 9) {
        uint8_t *bytes = (uint8_t *) data.bytes;
        uint8_t flag = bytes[0];
        isXRandom = (flag & IS_FROMXRANDOM_FLAG) == IS_FROMXRANDOM_FLAG;
    }
    return isXRandom;
}
@end