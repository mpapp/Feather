//
//  MPTreeItem.h
//  Feather
//
//  Created by Matias Piipari on 30/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

/** A protocol for items in a tree hierarchy (e.g. source list items). */
@protocol MPTreeItem < NSObject>
@property (readwrite, copy) NSString *title;
@property (readonly) id<MPTreeItem> parent;
@property (readonly, strong) NSArray *children;

/** Siblings are the children of self's parent, **including self**. */
@property (readonly, strong) NSArray *siblings;

@property (readonly) NSUInteger childCount;
@property (readonly) BOOL hasChildren;

/** The properties such as title are intended to be mutable by the user. */
@property (readonly) BOOL isEditable;

@property (readonly) NSInteger priority;

@property (readonly, weak) id packageController;

- (BOOL)save;

@end