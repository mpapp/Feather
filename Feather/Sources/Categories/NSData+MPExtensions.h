//
//  MPExtensions+NSData.h
//  Manuscripts
//
//  Created by Matias Piipari on 29/03/2013.
//  Copyright (c) 2013 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

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

@end
