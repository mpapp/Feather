//
//  NSDictionary+Feather.h
//  Feather
//
//  Created by Matias Piipari on 04/02/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *_Nonnull const MPDictionaryExtensionErrorDomain;

typedef NS_ENUM(NSUInteger, MPDictionaryExtensionErrorCode) {
    MPDictionaryExtensionErrorCodeUnexpectedDictionaryData = 1
};

@interface NSDictionary <K,V> (Feather)

- (nonnull NSMutableDictionary<K, V> *)mutableDeepContainerCopy;
- (nonnull NSMutableDictionary *)dictionaryOfSetsWithDictionaryOfArrays;

- (BOOL)containsObject:(nonnull id)object;
- (BOOL)containsObjectForKey:(nonnull id)key;

- (nullable id)anyObjectMatching:(BOOL(^_Nonnull)(_Nonnull id evaluatedKey, _Nullable id evaluatedObject))patternBlock;

- (nonnull NSDictionary *)dictionaryWithObjectsMatching:(BOOL(^_Nonnull)(_Nonnull id evaluatedKey, _Nonnull id evaluatedObject))patternBlock;

+ (nullable NSDictionary *)decodeFromJSONString:(nonnull NSString *)s error:(NSError *_Nullable *_Nullable)error;

- (nullable NSString *)JSONStringRepresentation:(NSError *_Nullable *_Nullable)err;

@end

extern NSDictionary *_Nonnull MPDictionaryFromDictionaries(NSInteger n, ...);
extern NSDictionary *_Nonnull MPDictionaryFromTwoDictionaries(NSDictionary *_Nonnull d1, NSDictionary *_Nonnull d2);

/**
 * Converts an immutable NSDictionary into an NSMutableDictionary. Returns the argument as is if it is already an NSMutableDictionary instance.
 */
extern NSMutableDictionary *_Nonnull MPMutableDictionaryForDictionary(NSDictionary * _Nonnull d);

extern NSMutableDictionary *_Nonnull MPMutableDictionaryFromDictionaries(NSInteger n, ...);
extern NSMutableDictionary *_Nonnull MPMutableDictionaryFromTwoDictionaries(NSDictionary *_Nonnull d1, NSDictionary *_Nonnull d2);
