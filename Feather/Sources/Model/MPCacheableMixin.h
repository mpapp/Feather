//
//  MPCacheableMixin.h
//  Feather
//
//  Created by Matias Piipari on 03/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPCacheable.h"

@interface MPCacheableMixin : NSObject <MPCacheable>

+ (nonnull NSDictionary<NSString *, NSSet<NSString *> *> *)cachedPropertiesByClassNameForBaseClass:(nonnull Class)cls;

+ (void)clearCachedValues:(nonnull id<MPCacheable>)cacheable;

@end
