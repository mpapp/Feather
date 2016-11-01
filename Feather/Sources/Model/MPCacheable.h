//
//  MPCacheable.h
//  Feather
//
//  Created by Matias Piipari on 03/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Foundation;

@protocol MPCacheable <NSObject>

@optional
+ (nonnull NSDictionary<NSString *, NSSet<NSString *> *> *)cachedPropertiesByClassName;
- (void)clearCachedValues;
- (void)refreshCachedValues;

/** 
 * Returning YES indicates that objects of this class have properties
 * that can only be safely accessed and cleared on the main thread.
 * Returning NO indicates that no such safety measure is needed.
 *
 * In the implementation provided by MPCacheableMixin isolation is enforced at the time of writing
 * only at the level of accessing the cache. 
 * 
 * NOTE! You MUST provide implementation of this method, MPCacheableMixin does not provide a default.
 */
+ (BOOL)hasMainThreadIsolatedCachedProperties;

@end
