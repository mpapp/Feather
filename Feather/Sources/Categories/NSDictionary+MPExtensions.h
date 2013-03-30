//
//  NSDictionary+Manuscripts.h
//  Manuscripts
//
//  Created by Matias Piipari on 04/02/2013.
//  Copyright (c) 2013 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSDictionary (Manuscripts)

- (NSMutableDictionary *)mutableDeepContainerCopy;
- (NSMutableDictionary *)dictionaryOfSetsWithDictionaryOfArrays;

- (BOOL)containsObject:(id)object;
- (BOOL)containsObjectForKey:(id)key;

@end


extern NSDictionary *MPDictionaryFromDictionaries(NSInteger n, ...);
extern NSDictionary *MPDictionaryFromTwoDictionaries(NSDictionary *d1, NSDictionary *d2);

/**
 * Converts an immutable NSDictionary into an NSMutableDictionary. Returns the argument as is if it is already an NSMutableDictionary instance.
 */
extern NSMutableDictionary *MPMutableDictionaryForDictionary(NSDictionary *d);

extern NSMutableDictionary *MPMutableDictionaryFromDictionaries(NSInteger n, ...);
extern NSMutableDictionary *MPMutableDictionaryFromTwoDictionaries(NSDictionary *d1, NSDictionary *d2);
