//
//  MPObjectWrappingSection.h
//  Feather
//
//  Created by Matias Piipari on 19/05/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

@import Foundation;

#import "MPVirtualSection.h"
#import "MPPlaceHolding.h"
#import "MPTreeItem.h"
#import "MPThumbnailable.h"
#import "MPCacheableMixin.h"

#import "MPTitledProtocol.h"

@protocol MPTreeItem;
@class MPManagedObject;

@interface MPObjectWrappingSection : MPVirtualSection

@property (readonly, copy, nullable) NSString *extendedTitle;

/** The object being wrapped. */
@property (readonly, strong, nullable) MPManagedObject<MPTitledProtocol, MPPlaceHolding, MPThumbnailable, MPTreeItem> *wrappedObject;

// FIXME: make this readonly.
/** The children of the wrapped object, each conformant to MPTreeItem. */
@property (readwrite, strong, nonnull) NSArray<id<MPTreeItem>> *wrappedChildren;

- (nonnull instancetype)init NS_UNAVAILABLE;

- (nonnull instancetype)initWithParent:(nonnull id<MPTreeItem>)parentItem wrappedObject:(nonnull MPManagedObject<MPTitledProtocol, MPPlaceHolding> *)obj;

/** Create an array of MPObjectWrappingSection objects with the specified parent. */
+ (nonnull NSArray *)arrayOfWrappedObjects:(nonnull NSArray<id<MPTitledProtocol, MPPlaceHolding>> *)wrappedObjects
                                withParent:(nonnull id<MPTreeItem>)parent;

@end