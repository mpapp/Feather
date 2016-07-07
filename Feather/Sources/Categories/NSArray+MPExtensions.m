//
//  NSArray+Feather.m
//  Feather
//
//  Created by Matias Piipari on 05/01/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "NSArray+MPExtensions.h"
#import "MPJSONRepresentable.h"

NSString *_Nonnull const MPArrayExtensionErrorDomain = @"@MPArrayExtensionErrorDomain";


@implementation NSArray (FeatherTypeParameterized)

- (NSArray *)mapObjectsUsingBlock:(id(^)(id o, NSUInteger idx))mapBlock {
    NSMutableArray *map = [NSMutableArray arrayWithCapacity:self.count];
    
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        id mappedVal = mapBlock(obj, idx);
        NSParameterAssert(mappedVal); // not sure if this needs to be non-nil?
        [map addObject:mappedVal ? mappedVal : [NSNull null]];
    }];
    
    return [map copy];
}

- (NSArray *)nilFilteredMapUsingBlock:(id(^)(id o, NSUInteger idx))mapBlock {
    NSMutableArray *map = [NSMutableArray arrayWithCapacity:self.count];
    
    NSUInteger i = 0;
    for (id obj in self) {
        id mappedVal = mapBlock(obj, i++);
        if (mappedVal) {
            [map addObject:mappedVal];
        }
    }
    
    return [map copy];
}

- (id)firstObjectMatching:(BOOL(^)(id evalutedObject))patternBlock {
    NSUInteger i;
    return [self firstObjectMatching:patternBlock index:&i];
}

- (id)firstObjectMatching:(BOOL(^)(id evalutedObject))patternBlock index:(NSUInteger *)index {
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

- (NSArray *)filteredArrayMatching:(BOOL(^)(id evalutedObject))patternBlock {
    // FIXME: Implement without requiring a temporary NSPredicate object
    return [self filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return patternBlock(evaluatedObject);
    }]];
}

- (NSArray *)subarrayUpToIncludingIndex:(NSUInteger)i
{
    if (self.count < 1) {
        return self;
    }
    
    if (i > (self.count - 1)) {
        i = self.count - 1;
    }
    
    NSArray *a = [self subarrayWithRange:NSMakeRange(0, i + 1)];
    return a;
}

- (NSArray *)subarrayFromIndex:(NSUInteger)i
{
    NSAssert(i < self.count, @"Expecting from index %@ to be smaller than the count %@", @(i), @(self.count));
    return [self subarrayWithRange:NSMakeRange(i, self.count - i)];
}

- (NSArray *)arrayByRemovingObject:(id)obj
{
    NSMutableArray *array = [self mutableCopy];
    [array removeObject:obj];
    return array;
}

- (NSArray *)arrayByRemovingLastObject {
    if (self.count <= 1) {
        return @[];
    }
    
    return [self subarrayWithRange:NSMakeRange(0, self.count - 1)];
}

- (NSArray *)reversedArray {
    return self.reverseObjectEnumerator.allObjects;
}

- (NSArray *)arrayByRandomizingOrder
{
    NSMutableArray *randomised = [NSMutableArray arrayWithArray:self];
    
    NSUInteger count = [randomised count];
    for (NSUInteger i = 0; i < count; ++i)
    {
        // Select a random element between i and end of array to swap with.
        NSInteger nElements = count - i;
        NSInteger n = (arc4random() % nElements) + i;
        [randomised exchangeObjectAtIndex:i withObjectAtIndex:n];
    }
    
    return randomised.copy;
}

@end

@implementation NSArray (Feather)

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

- (BOOL)allObjectsAreSubclassesOfClasses:(NSArray *)classes {
    NSParameterAssert(classes.count > 0);
    
    if (self.count == 0)
        return NO;
    
    for (id o in self) {
        BOOL isOneOf = NO;
        for (Class c in classes) {
            if ([o isKindOfClass:c]) {
                isOneOf = YES;
                continue;
            }
        }
        if (!isOneOf) {
            return NO;
        }
    }

    return YES;
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

- (void)matchingValueForKey:(NSString *)key value:(void(^)(const BOOL valueMatches, const id value))valueBlock
{
    NSArray *values = [self valueForKey:key];
    NSSet *valueSet = [NSSet setWithArray:values];
    
    if (valueSet.count == 0 || valueSet.count > 1) { valueBlock(NO, nil); return; }
    else if (valueSet.count == 1) { valueBlock(YES, [valueSet anyObject]); return; }
}

// http://stackoverflow.com/questions/8569388/nsarray-of-united-arrays
-(NSArray *)arrayByFlatteningArray
{
    return [self valueForKeyPath:@"@unionOfArrays.self"];
}

+ (NSDictionary *)decodeFromJSONString:(NSString *)s error:(NSError **)error {
    NSDictionary *d = [NSJSONSerialization JSONObjectWithData:[s dataUsingEncoding:NSUTF8StringEncoding] options:0 error:error];
    if (![d isKindOfClass:NSArray.class]) {
        if (error) {
            *error = [NSError errorWithDomain:MPArrayExtensionErrorDomain
                                         code:MPArrayExtensionErrorCodeUnexpectedArrayData
                                     userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Data cannot be decoded as an array: %@", d.class]}];
            return nil;
        }
    }
    return d;
}


- (NSString *)JSONStringRepresentation:(NSError **)err
{
    NSArray *objs = [self mapObjectsUsingBlock:^id(id o, NSUInteger idx) {
        BOOL requiresJSONStringRep
            = [o conformsToProtocol:@protocol(MPJSONRepresentable)]
                || [o isKindOfClass:NSArray.class]
                || [o isKindOfClass:NSDictionary.class];
        
        if (requiresJSONStringRep) {
            id rep = requiresJSONStringRep ? [o JSONStringRepresentation:err] : o;
            
            // TODO: don't de/reserialise just to get objects into a JSON encodable state.
            if (!rep)
                return [NSNull null];
            
            rep = [NSJSONSerialization JSONObjectWithData:[rep dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            return rep ? rep : [NSNull null];
        }
        else {
            return o;
        }
    }];
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:objs options:NSJSONWritingPrettyPrinted error:err];
    if (!data)
        return nil;
    
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return str;
}

// from http://stackoverflow.com/questions/3791265/generating-permutations-of-nsarray-elements
NSInteger *pc_next_permutation(NSInteger *p, const NSInteger size) {
    // slide down the array looking for where we're smaller than the next guy
    NSInteger i;
    for (i = size - 1; p[i] >= p[i + 1]; --i) { }
    
    // if this doesn't occur, we've finished our permutations
    // the array is reversed: (1, 2, 3, 4) => (4, 3, 2, 1)
    if (i == -1)
        return NULL;
    
    NSInteger j;
    // slide down the array looking for a bigger number than what we found before
    for (j = size; p[j] <= p[i]; --j) { }
    
    // swap them
    NSInteger tmp = p[i]; p[i] = p[j]; p[j] = tmp;
    
    // now reverse the elements in between by swapping the ends
    for (++i, j = size; i < j; ++i, --j) {
        tmp = p[i]; p[i] = p[j]; p[j] = tmp;
    }
    
    return p;
}

- (NSArray *)allPermutations
{
    NSInteger size = [self count];
    
    if (size == 0) {
        return @[];
    }
    
    NSInteger *perm = malloc(size * sizeof(NSInteger));
    
    for (NSInteger idx = 0; idx < size; ++idx)
        perm[idx] = idx;
    
    NSInteger j = 0;
    
    --size;
    
    NSMutableArray *perms = [NSMutableArray array];
    
    do {
        NSMutableArray *newPerm = [NSMutableArray array];
        
        for (NSInteger i = 0; i <= size; ++i)
            [newPerm addObject:[self objectAtIndex:perm[i]]];
        
        [perms addObject:newPerm];
    } while ((perm = pc_next_permutation(perm, size)) && ++j);
    
    return perms;
}

@end


@implementation NSMutableArray (Feather)

- (id) popObject
{
    if (self.count > 0)
    {
        id object = self[0];
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
            __emptyArray = @[];
        }
        
        return __emptyArray;
    }
}
