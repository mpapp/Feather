//
//  NSSet+Feather.m
//  Feather
//
//  Created by Matias Piipari on 05/02/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "NSSet+MPExtensions.h"

@implementation NSSet (Feather)

- (NSMutableSet *)mutableDeepContainerCopy
{
    NSMutableSet *ret = [[NSMutableSet alloc] initWithCapacity:self.count];
    for (id val in self) {
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

- (NSSet *)mapObjectsUsingBlock:(id (^)(id obj))block {
    NSMutableSet *result = [NSMutableSet setWithCapacity:[self count]];
    [self enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        [result addObject:block(obj)];
    }];
    return [result copy];
}

- (NSSet *)nilFilteredMapUsingBlock:(id (^)(id obj))block {
    NSMutableSet *result = [NSMutableSet setWithCapacity:[self count]];
    [self enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        id r = block(obj);
        
        if (r) {
            [result addObject:r];
        }
    }];
    return [result copy];
}

- (NSSet *)filteredSetMatching:(BOOL(^)(id evalutedObject))patternBlock {
    return [self filteredSetUsingPredicate:
                [NSPredicate predicateWithBlock:
                    ^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return patternBlock(evaluatedObject);
    }]];
}

@end
