//
//  MPExtensions+NSData.m
//  Feather
//
//  Created by Matias Piipari on 29/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "NSData+MPExtensions.h"

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonCryptor.h>

#import <zlib.h>

#import "NSData+Base64.h"

// FIXME: Find the source for these.

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
	return [[self sha1HMacWithKey:key] base64EncodingWithLineLength:-1];
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
	return [[self sha256HMacWithKey:key] base64EncodingWithLineLength:-1];
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
        [hex appendString:@(temp)];
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



@implementation NSData (AESAdditions)

- (NSData *)AES256EncryptWithKey:(NSString*)key {
    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyPtr[kCCKeySizeAES256 + 1]; // room for terminator (unused)
    bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
    
    // fetch key data
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [self length];
    
    //See the doc: For block ciphers, the output size will always be less than or
    //equal to the input size plus the size of one block.
    //That's why we need to add the size of one block here
    size_t bufferSize           = dataLength + kCCBlockSizeAES128;
    void* buffer                = malloc(bufferSize);
    
    size_t numBytesEncrypted    = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL /* initialization vector (optional) */,
                                          [self bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesEncrypted);
    
    if (cryptStatus == kCCSuccess)
    {
        //the returned NSData takes ownership of the buffer and will free it on deallocation
        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    
    free(buffer); //free the buffer;
    return nil;
}

- (NSData *)AES256DecryptWithKey:(NSString*)key {
    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyPtr[kCCKeySizeAES256 + 1]; // room for terminator (unused)
    bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
    
    // fetch key data
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [self length];
    
    //See the doc: For block ciphers, the output size will always be less than or
    //equal to the input size plus the size of one block.
    //That's why we need to add the size of one block here
    size_t bufferSize           = dataLength + kCCBlockSizeAES128;
    void* buffer                = malloc(bufferSize);
    
    size_t numBytesDecrypted    = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL /* initialization vector (optional) */,
                                          [self bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesDecrypted);
    
    if (cryptStatus == kCCSuccess)
    {
        //the returned NSData takes ownership of the buffer and will free it on deallocation
        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    
    free(buffer); //free the buffer;
    return nil;
}

@end
