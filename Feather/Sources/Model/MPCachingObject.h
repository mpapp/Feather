//
//  MPCachingObject.h
//  Manuscripts
//
//  Created by Matias Piipari on 19/10/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

/** Classes which conform to MPCachingObject contain cached data which can be cleared or refreshed (reloaded immediately, non-lazily). */
@protocol MPCachingObject <NSObject>

/** Clears cached values. */
- (void)clearCachedValues;

/** Refreshes cached values: clears, then reloads all values. */
- (void)refreshCachedValues;
@end
