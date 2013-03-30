//
//  MPExtensions+NSData.m
//  Manuscripts
//
//  Created by Matias Piipari on 29/03/2013.
//  Copyright (c) 2013 Manuscripts.app Limited. All rights reserved.
//

#import "NSData+MPExtensions.h"

@implementation NSData (MPExtensions)


- (NSString *)md5DigestString
{
	return [[self md5Digest] hexadecimalString];
}

- (NSData *)md5Digest
{
	NSMutableData *digest = [NSMutableData dataWithLength:CC_MD5_DIGEST_LENGTH];
	if (digest && CC_MD5([self bytes], (unsigned int)[self length], [digest mutableBytes]))
	{
		return [NSData dataWithData: digest];
	}
	return nil;
}

- (NSString *)sha1DigestString
{
	return [[self sha1Digest] hexadecimalString];
}

- (NSData *)sha1Digest
{
	NSMutableData *digest = [NSMutableData dataWithLength:CC_SHA1_DIGEST_LENGTH];
	if (digest && CC_SHA1([self bytes], (unsigned int)[self length], [digest mutableBytes]))
	{
		return [NSData dataWithData: digest];
	}
	return nil;
}

- (NSString *)sha1HMacStringWithKey:(NSString *)key
{
	return [[self sha1HMacWithKey:key] base64Encoded];
}

- (NSData *)sha1HMacWithKey:(NSString *)key
{
	NSMutableData *hmac = [NSMutableData dataWithLength:CC_SHA1_DIGEST_LENGTH];
	const char* k = [key cStringUsingEncoding:NSUTF8StringEncoding];
	if (hmac)
	{
		CCHmac(kCCHmacAlgSHA1, k, strlen(k), [self bytes], [self length], [hmac mutableBytes]);
		return [NSData dataWithData: hmac];
	}
	return nil;
}


- (NSString *)sha256HMacStringWithKey:(NSString *)key
{
	return [[self sha256HMacWithKey:key] base64Encoded];
}

- (NSData *)sha256HMacWithKey:(NSString *)key
{
	NSMutableData *hmac = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
	const char* k = [key cStringUsingEncoding:NSUTF8StringEncoding];
	if (hmac)
	{
		CCHmac(kCCHmacAlgSHA256, k, strlen(k), [self bytes], [self length], [hmac mutableBytes]);
		return [NSData dataWithData: hmac];
	}
	return nil;
}


- (NSString *)hexadecimalString
{
    NSMutableString *hex = [NSMutableString string];
    unsigned char *bytes = (unsigned char *)[self bytes];
    char temp[3];
    int i = 0;
	
    for (i = 0; i < [self length]; i++)
	{
        temp[0] = temp[1] = temp[2] = 0;
        (void)sprintf(temp, "%02x", bytes[i]);
        [hex appendString:[NSString stringWithUTF8String:temp]];
    }
    return hex;
}

- (NSUInteger)crc32Checksum
{
	// CRC32 implementation using zlib
	// according to this link, only the upper 16 bits are well distributed: http://home.comcast.net/~bretm/hash/8.html
	// according to this link, actually all bits are good: http://stackoverflow.com/questions/2694740/can-one-construct-a-good-hash-function-using-crc32c-as-a-base/3045334#3045334
	
	uLong crcFromZlib = crc32(0L, Z_NULL, 0);
	crcFromZlib = crc32(crcFromZlib, [self bytes], (unsigned int)[self length]);
	
	return (NSUInteger)crcFromZlib;
}

@end
