//
//  MPVirtualSection_Protected.h
//  Manuscripts
//
//  Created by Matias Piipari on 24/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Feather/MPVirtualSection.h>

@interface MPVirtualSection ()
@property (readwrite, weak, nullable) id<MPTreeItem> parent;
@property (readwrite, strong, nullable) NSImage *cachedThumbnailImage;
@property (readwrite, strong, nullable) NSArray<id<MPTreeItem>> *cachedChildren;
@property (readwrite, strong, nullable) NSArray *cachedRepresentedObjects;

@property (readwrite) BOOL childrenCacheIsStale;
@property (readwrite) BOOL representedObjectsCacheIsStale;

- (void)observeManagedObjectChanges;

@end

@interface MPObjectWrappingSection ()
{
    Class _managedObjectClass;
    NSArray *_representedObjects;
}

@property (readwrite, copy, nullable) NSString *extendedTitle;
@property (readwrite, strong, nullable) Class representedObjectClass;
@property (readwrite, strong, nonnull) NSArray *representedObjects;
@property (readwrite, strong, nonnull) NSArray *observedManagedObjectClasses;
@end

