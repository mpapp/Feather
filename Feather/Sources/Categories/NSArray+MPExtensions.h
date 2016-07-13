//
//  NSArray+Feather.h
//  Feather
//
//  Created by Matias Piipari on 05/01/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Foundation;

#define MPLastIndexInArray(a) (a.count - 1)

typedef NS_ENUM(NSUInteger, MPValueToggleResult) {
    MPValueToggleResultRemoved = 0,
    MPValueToggleResultAdded = 1
};

typedef NS_ENUM(NSUInteger, MPArrayExtensionErrorCode) {
    MPArrayExtensionErrorCodeUnexpectedArrayData = 1
};

@interface NSArray <T> (FeatherTypeParameterized)

/** Returns a copy of the array iterated from end to beginning. */
@property (readonly, copy, nonnull) NSArray<T> *reversedArray;

/** Array of the same length, with order of items randomized with arc4random. */
@property (readonly, copy, nonnull) NSArray<T> *arrayByRandomizingOrder;

- (nonnull NSArray *)mapObjectsUsingBlock:(_Nonnull id(^ _Nonnull)(_Nonnull T o, NSUInteger idx))mapBlock;

- (nonnull NSArray *)nilFilteredMapUsingBlock:(_Nonnull id(^ _Nonnull)(_Nonnull id o, NSUInteger idx))mapBlock;

- (nullable T)firstObjectMatching:(BOOL(^ _Nonnull)(_Nonnull T evaluatedObject))patternBlock;
- (nullable T)firstObjectMatching:(BOOL(^ _Nonnull)(_Nonnull T evaluatedObject))patternBlock index:(NSUInteger * _Nullable)index;
- (nonnull NSArray<T> *)filteredArrayMatching:(BOOL(^ _Nonnull)(_Nonnull T evaluatedObject))patternBlock;

- (nonnull NSArray<T> *)arrayByRemovingObject:(nonnull T)obj;

- (nonnull NSArray<T> *)arrayByRemovingLastObject;

- (nonnull NSArray<T> *)subarrayUpToIncludingIndex:(NSUInteger)i;
- (nonnull NSArray<T> *)subarrayFromIndex:(NSUInteger)i;

@end

@interface NSArray <T> (Feather)

- (nonnull NSMutableArray<T> *)mutableDeepContainerCopy;

- (nonnull NSSet *)allObjectSubclasses;

/** If all objects are subclasses of one or more of the classes given as an argument, returns YES, otherwise NO.
  * Returns NO for an empty array.
  * The classes array must not be empty. */
- (BOOL)allObjectsAreSubclassesOfClasses:(nonnull NSArray<Class> *)classes;
- (BOOL)allObjectsAreSubclassesOf:(nonnull Class)class;


/** Returns a flattened array (where objects contained inside arrays in the array are made top level objects). */
@property (readonly, copy, nonnull) NSArray *arrayByFlatteningArray;


- (void)matchingValueForKey:(nonnull NSString *)key value:(void(^ _Nonnull)(BOOL valueMatches, _Nullable id value))valueBlock;

/**  A JSON encodable string representation of the array. Objects in the array must all implement a method with selector -JSONStringRepresentation: */
- (nullable NSString *)JSONStringRepresentation:(NSError *_Nullable *_Nullable)err;

+ (nullable NSArray *)decodeFromJSONString:(nonnull NSString *)s error:(NSError *_Nullable *_Nullable)error;

- (nonnull NSArray<T> *)allPermutations;

@end


#define MPLastIndexInArray(a) (a.count - 1)


@interface NSMutableArray (Feather)

/** Removes and returns the first object in this mutable array. */
- (nullable id) popObject;

/** Inserts an object at the beginning of this mutable array. */
- (void)pushObject:(nonnull id)object;

/** Inserts all objects in the given array into the beginning of this mutable array, in the same order they appear in the source array. */
- (void)pushObjectsInArray:(nonnull NSArray *)array;

/** Adds the object in the array if it wasn't there, and removes it from there if it were present. */
- (MPValueToggleResult)toggleValue:(nonnull id)obj;

@end

extern NSArray *_Nonnull MPNilToEmptyArray(NSArray * _Nullable array);
