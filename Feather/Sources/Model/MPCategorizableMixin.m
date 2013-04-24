//
//  MPCategorizableMixin.m
//  Manuscripts
//
//  Created by Matias Piipari on 17/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPCategorizableMixin.h"

@implementation MPCategorizableMixin

+ (MPSortByPriorityBlock)sortByPriorityBlock
{
    return ^NSComparisonResult(id<MPCategorizable> a, id<MPCategorizable> b)
    {
        if ([a priority] > [b priority]) return NSOrderedDescending;
        if ([a priority] < [b priority]) return NSOrderedAscending;
        
        return [a.name caseInsensitiveCompare:b.name];
    };
}

@end
