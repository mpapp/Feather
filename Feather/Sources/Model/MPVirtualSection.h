//
//  MPVirtualSection.h
//  Manuscripts
//
//  Created by Matias Piipari on 13/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Foundation;

#import "MPPlaceHolding.h"
#import "MPTreeItem.h"
#import "MPThumbnailable.h"
#import "MPCacheableMixin.h"
#import "NSNotificationCenter+MPManagedObjectExtensions.h"
#import "MPTitledProtocol.h"

@class MPDatabasePackageController;

@interface MPVirtualSection : NSObject <MPTreeItem, MPCacheable, MPPlaceHolding, MPManagedObjectChangeObserver, MPTitledProtocol>

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

