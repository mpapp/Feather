//
//  MPCacheable.h
//  Feather
//
//  Created by Matias Piipari on 03/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MPCacheable <NSObject>

@optional
+ (NSDictionary *)cachedPropertiesByClassName;
- (void)clearCachedValues;
- (void)refreshCachedValues;

@end
