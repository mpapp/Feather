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

- (NSArray *)mapObjectsUsingBlock:(NSArray *(^)(id o, NSUInteger idx))mapBlock;

- (id)firstObject;
- (id)firstObjectMatching:(BOOL(^)(id evalutedObject))patternBlock;
- (id)firstObjectMatching:(BOOL(^)(id evalutedObject))patternBlock index:(NSUInteger *)index;
- (NSArray *)filteredArrayMatching:(BOOL(^)(id evalutedObject))patternBlock;

- (NSMutableArray *)mutableDeepContainerCopy;

- (NSSet *)allObjectSubclasses;
- (BOOL)allObjectsAreSubclassesOf:(Class)class;

- (NSArray *)arrayByRemovingObject:(id)obj;

- (NSArray *)subarrayFromIndex:(NSUInteger)i;

- (void)matchingValueForKey:(NSString *)key value:(void(^)(BOOL valueMatches, id value))valueBlock;

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

extern NSArray *MPArrayFromTwoArrays(NSArray *a1, NSArray *a2);
extern NSArray *MPArrayFromArrays(NSInteger n, ...);
extern NSMutableArray *MPMutableArrayForArray(NSArray *a);
extern NSMutableArray *MPMutableArrayFromTwoArrays(NSArray *a1, NSArray *a2);
extern NSMutableArray *MPMutableArrayFromArrays(NSInteger n, ...);
