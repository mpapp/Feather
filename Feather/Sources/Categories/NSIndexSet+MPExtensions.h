//
//  NSIndexSet+MPExtensions.h
//  Feather
//
//  Created by Matias Piipari on 18/04/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSIndexSet (MPExtensions)

- (NSArray *)mapAssociatedObjects:(NSArray *)objects
                       usingBlock:(id(^)(id o, NSUInteger idx))mapBlock;

- (id)firstAssociatedObject:(NSArray *)objects
                   matching:(BOOL(^)(id evalutedObject))patternBlock;

- (id)firstAssociatedObject:(NSArray *)objects
                   matching:(BOOL(^)(id evalutedObject))patternBlock
                      index:(NSUInteger *)index;

- (NSArray *)filteredAssociatedObject:(NSArray *)objects matching:(BOOL(^)(id evalutedObject))patternBlock;

@end
