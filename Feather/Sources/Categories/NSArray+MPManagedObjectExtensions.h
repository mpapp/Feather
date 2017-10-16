//
//  NSArray+MPManagedObjectExtensions.h
//  Manuscripts
//
//  Created by Matias Piipari on 28/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Foundation;

#import <Foundation/Foundation.h>

@protocol MPCategorizable;

@interface NSArray (MPManagedObjectExtensions)
- (NSArray<id<MPCategorizable>> *)sortedArrayUsingPriority;
@end
