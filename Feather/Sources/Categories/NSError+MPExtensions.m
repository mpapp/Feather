//
//  NSError+MPExtensions.m
//  Feather
//
//  Created by Markus on 2/1/13.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "NSError+MPExtensions.h"


NSString * const MPShouldPresentErrorKey = @"MPShouldPresentErrorKey";


@implementation NSError (Feather)

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

- (BOOL)shouldPresent
{
    id value = self.userInfo[MPShouldPresentErrorKey];
    if ([value respondsToSelector:@selector(boolValue)]) {
        return [value boolValue];
    }
    return NO;
}

- (NSError *)errorByMarkingAsShouldPresent
{
    NSDictionary *userInfo = @{MPShouldPresentErrorKey: @(YES)};
    
    if (self.userInfo)
    {
        NSMutableDictionary *md = [NSMutableDictionary dictionaryWithDictionary:self.userInfo];
        md[MPShouldPresentErrorKey] = @(YES);
        userInfo = [md copy];
    }
    
    NSError *error = [NSError errorWithDomain:self.domain code:self.code userInfo:userInfo];
    return error;
}

@end
