//
//  NSSet+Feather.h
//  Feather
//
//  Created by Matias Piipari on 05/02/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSSet<T> (Feather)

- (NSMutableSet<T> *)mutableDeepContainerCopy;

- (NSSet<T> *)mapObjectsUsingBlock:(id (^)(T obj))block;

- (NSSet *)nilFilteredMapUsingBlock:(id (^)(id obj))block;

- (NSSet<T> *)filteredSetMatching:(BOOL(^)(T evalutedObject))patternBlock;

@end