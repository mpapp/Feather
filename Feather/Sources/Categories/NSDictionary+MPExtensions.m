//
//  NSDictionary+Feather.m
//  Feather
//
//  Created by Matias Piipari on 04/02/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "NSDictionary+MPExtensions.h"
#import "NSArray+MPExtensions.h"
#import "NSSet+MPExtensions.h"


@implementation NSDictionary (Feather)

- (NSMutableDictionary *)mutableDeepContainerCopy
{
    NSMutableDictionary *ret = [[NSMutableDictionary alloc] initWithCapacity:[self count]];
    for (id key in [self allKeys])
    {
        id val = self[key];
        if ([val isKindOfClass:[NSArray class]] ||
            [val isKindOfClass:[NSSet class]] ||
            [val isKindOfClass:[NSDictionary class]])
        {
            ret[key] = [val mutableDeepContainerCopy];
        }
        else
        {
            ret[key] = val;
        }
    }
    
    return ret;
}

- (NSMutableDictionary *)dictionaryOfSetsWithDictionaryOfArrays
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:self.count];
    
    for (NSString *key in [self allKeys])
    {
        NSArray *value = self[key];
        assert([value isKindOfClass:[NSArray class]]);
        dict[key] = [NSSet setWithArray:self[key]];
    }
    
    return dict;
}

- (BOOL)containsObject:(id)object
{
    return [self.allValues containsObject:object];
}

- (BOOL)containsObjectForKey:(id)key
{
    return (self[key] != nil);
}

- (id)anyObjectMatching:(BOOL(^)(id evaluatedKey, id evaluatedObject))patternBlock
{
    __block id matchingObj = nil;
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (patternBlock(key, obj))
        {
            matchingObj = obj;
            *stop = YES;
        }
    }];
    
    return matchingObj;
}

- (NSDictionary *)dictionaryWithObjectsMatching:(BOOL(^)(id evaluatedKey, id evaluatedObject))patternBlock {
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:self.count];
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        if (patternBlock(key, obj))
            dict[key] = obj;
    }];
    
    return [dict copy];
}

@end


NSDictionary *MPDictionaryFromDictionaries(NSInteger n, ...)
{
	NSMutableDictionary *md = [NSMutableDictionary dictionary];
	
    va_list vargs;
    va_start(vargs, n);
	
    for (int i = 0; i < n; i++)
    {
        NSDictionary *d = va_arg(vargs, NSDictionary *);
        
        if (d != nil) {
            [md addEntriesFromDictionary:d];
        }
    }
    
    return md;
}

NSDictionary *MPDictionaryFromTwoDictionaries(NSDictionary *d1, NSDictionary *d2)
{
    va_list vargs;
    return MPDictionaryFromDictionaries(2, d1, d2, vargs);
}

NSMutableDictionary *MPMutableDictionaryForDictionary(NSDictionary *d)
{
    if (d == nil) {
        return [NSMutableDictionary dictionary];
    }
    
    if ([d isKindOfClass:NSMutableDictionary.class]) {
        return (NSMutableDictionary *)d;
    }
    
    return [NSMutableDictionary dictionaryWithDictionary:d];
}

NSMutableDictionary *MPMutableDictionaryFromDictionaries(NSInteger n, ...)
{
    va_list vargs;
    return (NSMutableDictionary *)MPDictionaryFromDictionaries(n, vargs);
}

NSMutableDictionary *MPMutableDictionaryFromTwoDictionaries(NSDictionary *d1, NSDictionary *d2)
{
    return (NSMutableDictionary *)MPDictionaryFromTwoDictionaries(d1, d2);
}