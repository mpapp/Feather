//
//  MPExtensions+NSData.h
//  Feather
//
//  Created by Matias Piipari on 29/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Foundation;

@interface NSData (MPExtensions)

- (NSString *)md5DigestString;

- (NSData *)md5Digest;

- (NSString *)sha1DigestString;

- (NSData *)sha1Digest;

- (NSString *)sha1HMacStringWithKey:(NSString *)key;

- (NSData *)sha1HMacWithKey:(NSString *)key;

- (NSString *)sha256HMacStringWithKey:(NSString *)key;

- (NSData *)sha256HMacWithKey:(NSString *)key;

- (NSString *)hexadecimalString;

- (NSUInteger)crc32Checksum;

- (NSString *)stringByDecodingAsUTF8;

@end

@interface NSData (AESAdditions)

- (NSData *)AES256EncryptWithKey:(NSString *)key;

- (NSData *)AES256DecryptWithKey:(NSString *)key;

@end