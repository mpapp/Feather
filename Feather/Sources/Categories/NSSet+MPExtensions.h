//
//  NSSet+Manuscripts.h
//  Manuscripts
//
//  Created by Matias Piipari on 05/02/2013.
//  Copyright (c) 2013 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSSet (Manuscripts)

- (NSMutableSet *)mutableDeepContainerCopy;

- (NSSet *)mapObjectsUsingBlock:(id (^)(id obj))block;

@end