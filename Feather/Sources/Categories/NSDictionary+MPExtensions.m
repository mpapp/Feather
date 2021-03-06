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
#import "NSString+MPExtensions.h"

#import "FeatherExtensions/MPJSONRepresentable.h"


NSString *const MPDictionaryExtensionErrorDomain = @"MPDictionaryExtensionErrorDomain";

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

+ (NSDictionary *)decodeFromJSONString:(NSString *)s error:(NSError **)error {
    NSDictionary *d = [NSJSONSerialization JSONObjectWithData:[s dataUsingEncoding:NSUTF8StringEncoding] options:0 error:error];
    if (![d isKindOfClass:NSDictionary.class]) {
        if (error) {
            *error = [NSError errorWithDomain:MPDictionaryExtensionErrorDomain
                                         code:MPDictionaryExtensionErrorCodeUnexpectedDictionaryData
                                     userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Data cannot be decoded as a dictionary: %@", d.class]}];
            return nil;
        }
    }
    return d;
}

- (NSString *)encodeAsJSON
{
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:self options:NSJSONWritingPrettyPrinted error:&error];
    assert(data);
    assert(!error);
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return s;
}

- (NSString *)JSONStringRepresentation:(NSError **)err
{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    
    for (id k in self) {
        id v = self[k];
        
        BOOL requiresJSONStringRep
        = [v conformsToProtocol:@protocol(MPJSONRepresentable)]
        || [v isKindOfClass:NSArray.class]
        || [v isKindOfClass:NSDictionary.class];
        
        if (requiresJSONStringRep) {
            id rep = [v JSONStringRepresentation:err];
            
            // TODO: don't de/reserialise just to get objects into a JSON encodable state.
            rep = [NSJSONSerialization JSONObjectWithData:[rep dataUsingEncoding:NSUTF8StringEncoding]
                                                  options:0 error:err];
            
            if (!rep)
                return nil;

            dict[k] = rep;
        }
        else {
            dict[k] = v; // other values assumed to be NSJSONSerialization compatible.
        }
    };
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:err];
    if (!data)
        return nil;
    
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return str;
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
