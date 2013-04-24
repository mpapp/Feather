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
#import "MPCacheableMixin.h"

#import "MPTitled.h"

@interface MPVirtualSection : NSObject
    <MPTreeItem, MPCacheable, MPPlaceHolding, MPManagedObjectChangeObserver>

@property (readonly, weak) id<MPTreeItem> parent;
@property (readonly, weak) id packageController;
@property (readonly, weak) Class representedObjectClass;

/** The objects this section corresponds to: for instance 'unplaced figures'.
  * MPVirtualSection declares these synonymous to -children, but subclasses can overload in a way where -children and -representedObjects return different arrays of objects. */
@property (readonly, strong) NSArray *representedObjects;

- (instancetype)initWithPackageController:(MPDatabasePackageController *)pkgController parent:(id<MPTreeItem>)parent;

@property (readonly, copy) NSString *thumbnailImageName;
@property (readonly, strong) NSImage *thumbnailImage;

@end

@interface MPObjectWrappingSection : MPVirtualSection

@property (readonly, copy) NSString *extendedTitle;
@property (readonly, strong) MPManagedObject<MPTitled, MPPlaceHolding> *wrappedObject;

- (instancetype)initWithParent:(id<MPTreeItem>)parentItem
                 wrappedObject:(MPManagedObject<MPTitled, MPPlaceHolding> *)obj;

+ (NSArray *)arrayOfWrappedObjects:(NSArray *)wrappedObjects
                        withParent:(id<MPTreeItem>)parent;

@end