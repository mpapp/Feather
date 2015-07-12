//
//  NSArray+Feather.h
//  Feather
//
//  Created by Matias Piipari on 05/01/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>


#define MPLastIndexInArray(a) (a.count - 1)

typedef enum MPValueToggleResult
{
    MPValueToggleResultRemoved = 0,
    MPValueToggleResultAdded = 1
} MPValueToggleResult;


@interface NSArray (Feather)

- (NSArray *)mapObjectsUsingBlock:(id(^)(id o, NSUInteger idx))mapBlock;

- (id)firstObject;
- (id)firstObjectMatching:(BOOL(^)(id evalutedObject))patternBlock;
- (id)firstObjectMatching:(BOOL(^)(id evalutedObject))patternBlock index:(NSUInteger *)index;
- (NSArray *)filteredArrayMatching:(BOOL(^)(id evalutedObject))patternBlock;

- (NSMutableArray *)mutableDeepContainerCopy;

- (NSSet *)allObjectSubclasses;

/** If all objects are subclasses of one or more of the classes given as an argument, returns YES, otherwise NO.
  * Returns NO for an empty array.
  * The classes array must not be empty. */
- (BOOL)allObjectsAreSubclassesOfClasses:(NSArray *)classes;
- (BOOL)allObjectsAreSubclassesOf:(Class)class;

- (NSArray *)arrayByRemovingObject:(id)obj;

- (NSArray *)subarrayFromIndex:(NSUInteger)i;

- (NSArray *)arrayByFlatteningArray;

- (void)matchingValueForKey:(NSString *)key value:(void(^)(BOOL valueMatches, id value))valueBlock;

/**  A JSON encodable string representation of the array. Objects in the array must all implement a method with selector -JSONStringRepresentation: */
- (NSString *)JSONStringRepresentation:(NSError **)err;

- (NSArray *)allPermutations;

- (NSArray *)arrayByRandomizingOrder;

@end


#define MPLastIndexInArray(a) (a.count - 1)


@interface NSMutableArray (Feather)

/** Removes and returns the first object in this mutable array. */
- (id) popObject;

/** Inserts an object at the beginning of this mutable array. */
- (void) pushObject:(id)object;

/** Inserts all objects in the given array into the beginning of this mutable array, in the same order they appear in the source array. */
- (void) pushObjectsInArray:(NSArray *)array;

/** Adds the object in the array if it wasn't there, and removes it from there if it were present. */
- (MPValueToggleResult)toggleValue:(id)obj;

@end


extern NSArray *MPNilToEmptyArray(NSArray *array);
