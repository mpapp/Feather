//
//  NSIndexSet+MPExtensions.m
//  Feather
//
//  Created by Matias Piipari on 18/04/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import "NSIndexSet+MPExtensions.h"

@implementation NSIndexSet (MPExtensions)

- (NSArray *)mapAssociatedObjects:(NSArray *)objects
                       usingBlock:(id(^)(id o, NSUInteger idx))mapBlock
{
    NSMutableArray *map = [NSMutableArray arrayWithCapacity:self.count];
    [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        id mappedVal = mapBlock(objects[idx], idx);
        assert(mappedVal);
        [map addObject:mappedVal ? mappedVal : [NSNull null]];
    }];
    return [map copy];
}

- (id)firstAssociatedObject:(NSArray *)objects
                   matching:(BOOL(^)(id evalutedObject))patternBlock
{
    NSUInteger i;
    return [self firstAssociatedObject:objects matching:patternBlock index:&i];
}

- (id)firstAssociatedObject:(NSArray *)objects
                   matching:(BOOL(^)(id evalutedObject))patternBlock
                      index:(NSUInteger *)index
{
    __block id matchingObj = nil;
    [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        id evaluatedObj = objects[idx];
        if (patternBlock(evaluatedObj))
        {
            if (index) { *index = idx; }
            matchingObj = evaluatedObj;
            *stop = YES;
        }
    }];
    return matchingObj;
}

- (NSArray *)filteredAssociatedObject:(NSArray *)objects matching:(BOOL(^)(id evalutedObject))patternBlock
{
    NSMutableArray *filteredObjects = [NSMutableArray arrayWithCapacity:objects.count];
    [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        id object = objects[idx];
        if (patternBlock(object))
            [filteredObjects addObject:object];
    }];
    
    return filteredObjects;
}

@end
