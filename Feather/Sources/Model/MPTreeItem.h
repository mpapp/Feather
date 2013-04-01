//
//  MPTreeItem.h
//  Feather
//
//  Created by Matias Piipari on 30/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

/** A protocol for items in a tree hierarchy (e.g. source list items). */
@protocol MPTreeItem <NSObject>
@property (readwrite, copy) NSString *title;
@property (readonly) id<MPTreeItem> parent;
@property (readonly, strong) NSArray *children;
@property (readonly, strong) NSArray *siblings;
@property (readonly) NSUInteger childCount;
@property (readonly) BOOL hasChildren;

@property (readonly) NSInteger priority;

- (id)save;

@end