//
//  NSArray+MPManagedObjectExtensions.m
//  Manuscripts
//
//  Created by Matias Piipari on 28/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "NSArray+MPManagedObjectExtensions.h"

#import "MPCategorizableMixin.h"

@implementation NSArray (MPManagedObjectExtensions)

- (NSArray *)sortedArrayUsingPriority
{
    NSArray *sortedArray = [self sortedArrayUsingComparator:
                            ^NSComparisonResult(id<MPCategorizable> obj1,
                                                id<MPCategorizable> obj2)
                            {
                                NSInteger priority1 = [obj1 priority];
                                NSInteger priority2 = [obj2 priority];
                                return [@(priority1) compare:@(priority2)];
                            }];
    
    return sortedArray;
}

@end
