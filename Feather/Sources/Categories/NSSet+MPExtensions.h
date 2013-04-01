//
//  NSSet+Feather.h
//  Feather
//
//  Created by Matias Piipari on 05/02/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSSet (Feather)

- (NSMutableSet *)mutableDeepContainerCopy;

- (NSSet *)mapObjectsUsingBlock:(id (^)(id obj))block;

@end