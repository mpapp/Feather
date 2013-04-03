//
//  NSArray+MPManagedObjectExtensions.m
//  Manuscripts
//
//  Created by Matias Piipari on 28/03/2013.
//  Copyright (c) 2013 Manuscripts.app Limited. All rights reserved.
//

#import "NSArray+MPManagedObjectExtensions.h"

#import "MPManagedObject.h"
#import "MPCategorizableMixin.h"

@implementation NSArray (MPManagedObjectExtensions)

- (NSArray *)sortedArrayUsingPriority
{
    NSArray *sortedArray = [self sortedArrayUsingComparator:
                            ^NSComparisonResult(MPManagedObject<MPCategorizable> *obj1,
                                                MPManagedObject<MPCategorizable> *obj2)
                            {
                                NSInteger priority1 = [obj1 priority];
                                NSInteger priority2 = [obj2 priority];
                                return [@(priority1) compare:@(priority2)];
                            }];
    
    return sortedArray;
}

@end
