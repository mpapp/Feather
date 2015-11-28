//
//  MPVirtualSection_Protected.h
//  Manuscripts
//
//  Created by Matias Piipari on 24/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Feather/MPVirtualSection.h>

@interface MPVirtualSection ()
@property (readwrite, weak) id<MPTreeItem> parent;
@property (readwrite, strong) NSImage *cachedThumbnailImage;
@property (readwrite, strong) NSArray *cachedChildren;
@property (readwrite, strong) NSArray *cachedRepresentedObjects;

@property (readwrite) BOOL childrenCacheIsStale;
@property (readwrite) BOOL representedObjectsCacheIsStale;

- (void)observeManagedObjectChanges;

@end

@interface MPObjectWrappingSection ()
{
    Class _managedObjectClass;
    NSArray *_representedObjects;
}

@property (readwrite, copy) NSString *extendedTitle;
@property (readwrite, strong) Class representedObjectClass;
@property (readwrite, strong) NSArray *representedObjects;
@property (readwrite, strong) NSArray *observedManagedObjectClasses;
@end

