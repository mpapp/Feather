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

/** The item has a visible title */
@property (readonly, getter=isTitled) BOOL titled;

/** The item can be included or excluded from a selection of some sort (such as inclusion in a draft). */
@property (readonly) BOOL isOptional;

/** A transient property indicate whether the item is presently being edited. */
@property (readwrite) BOOL inEditMode;

@property (readonly) NSInteger priority;

@property (readonly, weak) id packageController;

- (BOOL)save;

@end

typedef NS_ENUM(NSInteger, MPOptionalTreeItemState) {
    MPOptionalTreeItemStateOn = NSOnState,
    MPOptionalTreeItemStateOff = NSOffState,
    MPOptionalTreeItemStateMixed = NSMixedState
};

@protocol MPOptionalTreeItem <MPTreeItem>

/** Objects whose isOptional=YES can be set a state in context of a given object. */
- (void)setState:(MPOptionalTreeItemState)state inContextOfObject:(id)object;

/** Objects whose isOptional=YES are queried with this method for their state. */
- (MPOptionalTreeItemState)stateInContextOfObject:(id)object;

/** Optional tree items should have a cell state value representation. */
- (NSCellStateValue)cellStateValueInContextOfObject:(id)object;

@end