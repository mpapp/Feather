//
//  NSIndexSet+MPExtensions.h
//  Feather
//
//  Created by Matias Piipari on 18/04/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSIndexSet <T> (MPExtensions)

- (NSArray<T> *)mapAssociatedObjects:(NSArray<T> *)objects
                       usingBlock:(id(^)(id o, NSUInteger idx))mapBlock;

- (T)firstAssociatedObject:(NSArray<T> *)objects matching:(BOOL(^)(id evalutedObject))patternBlock;

- (T)firstAssociatedObject:(NSArray<T> *)objects
                  matching:(BOOL(^)(T evalutedObject))patternBlock
                     index:(NSUInteger *)index;

- (NSArray<T> *)filteredAssociatedObject:(NSArray<T> *)objects matching:(BOOL(^)(T evalutedObject))patternBlock;

@end
