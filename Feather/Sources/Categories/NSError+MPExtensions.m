//
//  NSError+MPExtensions.m
//  Manuscripts
//
//  Created by Markus on 2/1/13.
//  Copyright (c) 2013 Manuscripts.app Limited. All rights reserved.
//

#import "NSError+MPExtensions.h"


@implementation NSError (Manuscripts)

+ (NSError *)errorWithDomain:(NSString *)domain code:(NSInteger)code
                 description:(NSString *)description
{
    return [NSError errorWithDomain:domain code:code userInfo:@{NSLocalizedDescriptionKey:description}];
}

+ (NSError *)errorWithDomain:(NSString *)domain
                        code:(NSInteger)code
                 description:(NSString *)description
                      reason:(NSString *)reason
{
    NSError *error = [NSError errorWithDomain:domain
                                         code:code
                                     userInfo:@{NSLocalizedDescriptionKey: description, NSLocalizedFailureReasonErrorKey: reason}];
    return error;
}

+ (NSError *)errorWithDomain:(NSString *)domain
                        code:(NSInteger)code
                 description:(NSString *)description
             underlyingError:(NSError *)originalError
{
    NSError *error = [NSError errorWithDomain:domain
                                         code:code
                                     userInfo:@{NSLocalizedDescriptionKey: description, NSUnderlyingErrorKey: originalError}];
    return error;
}

@end
