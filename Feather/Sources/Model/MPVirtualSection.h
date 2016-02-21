//
//  MPVirtualSection.h
//  Manuscripts
//
//  Created by Matias Piipari on 13/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MPPlaceHolding.h"
#import "Feather.h"
#import "MPTreeItem.h"
#import "MPThumbnailable.h"
#import "MPCacheableMixin.h"

#import "MPTitledProtocol.h"

@class MPDatabasePackageController;

@interface MPVirtualSection : NSObject
    <MPTreeItem, MPCacheable, MPPlaceHolding, MPManagedObjectChangeObserver, MPTitledProtocol>

@property (readonly, weak, nullable) id<MPTreeItem> parent;
@property (readonly, weak, nullable) __kindof MPDatabasePackageController *packageController;
@property (readonly, weak, nullable) Class representedObjectClass;

/** The objects this section corresponds to: for instance 'unplaced figures'.
  * MPVirtualSection declares these synonymous to -children, but subclasses can overload in a way where -children and -representedObjects return different arrays of objects. */
@property (readonly, strong, nonnull) NSArray<id<MPTreeItem>> *representedObjects;

- (nonnull instancetype)init NS_UNAVAILABLE;

- (nonnull instancetype)initWithPackageController:(nonnull MPDatabasePackageController *)pkgController parent:(nonnull id<MPTreeItem>)parent NS_DESIGNATED_INITIALIZER;

@property (readonly, copy, nonnull) NSString *thumbnailImageName;
@property (readonly, strong, nonnull) NSImage *thumbnailImage;

@end

@interface MPObjectWrappingSection : MPVirtualSection 

@property (readonly, copy, nullable) NSString *extendedTitle;

/** The object being wrapped. */
@property (readonly, strong, nullable) MPManagedObject<MPTitledProtocol, MPPlaceHolding, MPThumbnailable, MPTreeItem> *wrappedObject;

// FIXME: make this readonly.
/** The children of the wrapped object, each conformant to MPTreeItem. */
@property (readwrite, strong, nonnull) NSArray<id<MPTreeItem>> *wrappedChildren;

- (nonnull instancetype)initWithParent:(nonnull id<MPTreeItem>)parentItem
                         wrappedObject:(nonnull MPManagedObject<MPTitledProtocol, MPPlaceHolding> *)obj;

/** Create an array of MPObjectWrappingSection objects with the specified parent. */
+ (nonnull NSArray *)arrayOfWrappedObjects:(nonnull NSArray<id<MPTitledProtocol, MPPlaceHolding>> *)wrappedObjects
                                withParent:(nonnull id<MPTreeItem>)parent;

@end