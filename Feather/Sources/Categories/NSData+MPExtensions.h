//
//  MPExtensions+NSData.h
//  Feather
//
//  Created by Matias Piipari on 29/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Foundation;

@interface NSData (MPExtensions)

- (nullable NSString *)md5DigestString;

- (nullable NSData *)md5Digest;

- (nullable NSString *)sha1DigestString;

- (nullable NSData *)sha1Digest;

- (nullable NSString *)sha1HMacStringWithKey:(nonnull NSString *)key;

- (nullable NSData *)sha1HMacWithKey:(nonnull NSString *)key;

- (nullable NSString *)sha256HMacStringWithKey:(nonnull NSString *)key;

- (nullable NSData *)sha256HMacWithKey:(nonnull NSString *)key;

- (nonnull NSString *)hexadecimalString;

- (NSUInteger)crc32Checksum;

- (nullable NSString *)stringByDecodingAsUTF8;

@end

@interface NSData (AESAdditions)

- (nullable NSData *)AES256EncryptWithKey:(nonnull NSString *)key;

- (nullable NSData *)AES256DecryptWithKey:(nonnull NSString *)key;

@end