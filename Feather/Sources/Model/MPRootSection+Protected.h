//
//  MPRootSection_Protected.h
//  Manuscripts
//
//  Created by Matias Piipari on 24/04/2013.
//  Copyright (c) 2013 Manuscripts.app Limited. All rights reserved.
//

#import "MPRootSection.h"

@interface MPRootSection ()
- (void)refreshCachedValues;
@property (readwrite) NSArray *cachedChildren;
@end