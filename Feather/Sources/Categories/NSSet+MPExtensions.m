//
//  NSSet+Manuscripts.m
//  Manuscripts
//
//  Created by Matias Piipari on 05/02/2013.
//  Copyright (c) 2013 Manuscripts.app Limited. All rights reserved.
//

#import "NSSet+Manuscripts.h"

@implementation NSSet (Manuscripts)

- (NSMutableSet *)mutableDeepContainerCopy
{
    NSMutableSet *ret = [[NSMutableSet alloc] initWithCapacity:self.count];
    for (id val in self)
    {
        if ([val isKindOfClass:[NSArray class]] ||
            [val isKindOfClass:[NSSet class]] ||
            [val isKindOfClass:[NSDictionary class]])
        {
            [ret addObject:[val mutableDeepContainerCopy]];
        }
        else
        {
            [ret addObject:val];
        }
    }
    return ret;
}

- (NSSet *)mapObjectsUsingBlock:(id (^)(id obj))block
{
    NSMutableSet *result = [NSMutableSet setWithCapacity:[self count]];
    [self enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        [result addObject:block(obj)];
    }];
    return [result copy];
}

@end
