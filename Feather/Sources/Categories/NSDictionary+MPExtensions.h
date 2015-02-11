//
//  NSDictionary+Feather.h
//  Feather
//
//  Created by Matias Piipari on 04/02/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSDictionary (Feather)

- (NSMutableDictionary *)mutableDeepContainerCopy;
- (NSMutableDictionary *)dictionaryOfSetsWithDictionaryOfArrays;

- (BOOL)containsObject:(id)object;
- (BOOL)containsObjectForKey:(id)key;

- (id)anyObjectMatching:(BOOL(^)(id evaluatedKey, id evaluatedObject))patternBlock;

- (NSDictionary *)dictionaryWithObjectsMatching:(BOOL(^)(id evaluatedKey, id evaluatedObject))patternBlock;


/** A method to convert an NSAppleEventDescriptor into an NSDictionary. */
+ (id)scriptingRecordWithDescriptor:(NSAppleEventDescriptor *)inDesc;

+ (NSDictionary *)decodeDictionaryFromJSONString:(NSString *)s;
- (NSString *)encodeAsJSON;

@end


extern NSDictionary *MPDictionaryFromDictionaries(NSInteger n, ...);
extern NSDictionary *MPDictionaryFromTwoDictionaries(NSDictionary *d1, NSDictionary *d2);

/**
 * Converts an immutable NSDictionary into an NSMutableDictionary. Returns the argument as is if it is already an NSMutableDictionary instance.
 */
extern NSMutableDictionary *MPMutableDictionaryForDictionary(NSDictionary *d);

extern NSMutableDictionary *MPMutableDictionaryFromDictionaries(NSInteger n, ...);
extern NSMutableDictionary *MPMutableDictionaryFromTwoDictionaries(NSDictionary *d1, NSDictionary *d2);
