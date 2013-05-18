//
//  NSArray+Feather.m
//  Feather
//
//  Created by Matias Piipari on 05/01/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "NSArray+MPExtensions.h"


@implementation NSArray (Feather)

- (id)firstObject { return self.count > 0 ? self[0] : nil; }

- (NSArray *)mapObjectsUsingBlock:(id(^)(id o, NSUInteger idx))mapBlock
{
    NSMutableArray *map = [NSMutableArray arrayWithCapacity:self.count];
    
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        id mappedVal = mapBlock(obj, idx);
        assert(mappedVal); // not sure if this needs to be non-nil?
        [map addObject:mappedVal ? mappedVal : [NSNull null]];
    }];
    
    return map;
}

- (id)firstObjectMatching:(BOOL(^)(id evalutedObject))patternBlock
{
    NSUInteger i;
    return [self firstObjectMatching:patternBlock index:&i];
}

- (id)firstObjectMatching:(BOOL(^)(id evalutedObject))patternBlock index:(NSUInteger *)index
{
    __block id matchingObj = nil;
    [self enumerateObjectsUsingBlock:^(id evaluatedObj, NSUInteger idx, BOOL *stop) {
        
        if (patternBlock(evaluatedObj))
        {
            if (index) { *index = idx; }
            matchingObj = evaluatedObj;
            *stop = YES;
        }
    }];
    return matchingObj;
}

- (NSArray *)filteredArrayMatching:(BOOL(^)(id evalutedObject))patternBlock
{
    // FIXME: Implement without requiring a temporary NSPredicate object
    return [self filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return patternBlock(evaluatedObject);
    }]];
}

- (NSMutableArray *)mutableDeepContainerCopy
{
    NSMutableArray *ret = [[NSMutableArray alloc] initWithCapacity:[self count]];
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

- (NSSet *)allObjectSubclasses
{
    return [NSSet setWithArray:[self valueForKey:@"class"]];
}

- (BOOL)allObjectsAreSubclassesOf:(Class)class
{
    if (self.count == 0) return NO;
    
    __block BOOL allAreSubclassesOf = YES;
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger i, BOOL *stop) {
        if (![obj isKindOfClass:class]) { *stop = YES; allAreSubclassesOf = NO; }
    }];
    
    return allAreSubclassesOf;
}

- (NSArray *)arrayByRemovingObject:(id)obj
{
    NSMutableArray *array = [self mutableCopy];
    [array removeObject:obj];
    return array;
}

- (void)matchingValueForKey:(NSString *)key value:(void(^)(const BOOL valueMatches, const id value))valueBlock
{
    NSArray *values = [self valueForKey:key];
    NSSet *valueSet = [NSSet setWithArray:values];
    
    if (valueSet.count == 0 || valueSet.count > 1) { valueBlock(NO, nil); return; }
    else if (valueSet.count == 1) { valueBlock(YES, [valueSet anyObject]); return; }
}

- (NSArray *)subarrayFromIndex:(NSUInteger)i
{
    assert(i < self.count);
	return [self subarrayWithRange:NSMakeRange(i, self.count - i)];
}

// http://stackoverflow.com/questions/8569388/nsarray-of-united-arrays
-(NSArray *)arrayByFlatteningArray
{
    return [self valueForKeyPath:@"@unionOfArrays.self"];
}

@end


@implementation NSMutableArray (Feather)

- (id) popObject
{
    if (self.count > 0)
    {
        id object = [self objectAtIndex:0];
        [self removeObjectAtIndex:0];
        return object;
    }
    return nil;
}

- (void) pushObject:(id)object
{
    [self insertObject:object atIndex:0];
}

- (void) pushObjectsInArray:(NSArray *)array
{
    if ((array != nil) && ([array count] > 0))
    {
        [self insertObjects:array atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [array count])]];
    }
}

- (MPValueToggleResult)toggleValue:(id)value
{
    if ([self containsObject:value])
    {
        [self removeObject:value];
        return MPValueToggleResultRemoved;
    }
    else
    {
        [self addObject:value];
        return MPValueToggleResultAdded;
    }
}

@end


NSArray *MPNilToEmptyArray(NSArray *array) {
    if (array != nil) {
        return array;
    } else {
        static NSArray *__emptyArray = nil;
        
        if (__emptyArray == nil) {
            __emptyArray = [NSArray array];
        }
        
        return __emptyArray;
    }
}


NSArray *MPArrayFromArrays(NSInteger n, ...)
{
	NSMutableArray *ma = [NSMutableArray arrayWithCapacity:n];
	
    va_list vargs;
    va_start(vargs, n);
	
    for (int i = 0; i < n; i++)
    {
        NSArray *array = va_arg(vargs, NSArray *);
        
        if (array != nil) {
            [ma addObjectsFromArray:array];
        }
    }
    
    return ma;
}

NSArray *MPArrayFromTwoArrays(NSArray *a1, NSArray *a2)
{
    va_list vargs;
    return MPArrayFromArrays(2, a1, a2, vargs);
}

NSMutableArray *BFMutableArrayForArray(NSArray *a)
{
    if (a == nil) {
        return [NSMutableArray array];
    }
    
    if ([a isKindOfClass:NSMutableArray.class]) {
        return (NSMutableArray *)a;
    }
    
    return [NSMutableArray arrayWithArray:a];
}

NSMutableArray *BFMutableArrayFromArrays(NSInteger n, ...)
{
    va_list vargs;
    return (NSMutableArray *)MPArrayFromArrays(n, vargs);
}

NSMutableArray *BFMutableArrayFromTwoArrays(NSArray *a1, NSArray *a2)
{
    return (NSMutableArray *)MPArrayFromTwoArrays(a1, a2);
}
