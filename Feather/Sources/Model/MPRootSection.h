//
//  MPRootSection.h
//  Manuscripts
//
//  Created by Matias Piipari on 19/12/2012.
//  Copyright (c) 2015 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Feather/Feather.h>
#import <Feather/MPTreeItem.h>
#import <Feather/MPCacheable.h>
#import <Feather/MPTitledProtocol.h>

extern NSString * _Nonnull const MPPasteboardTypeRootSection;

/** MPRootSection is an abstract base class for the root section objects (Sections, Authors, etc) in the application source list. */
@interface MPRootSection : NSObject <MPTreeItem, MPManagedObjectRecentChangeObserver, MPCacheable, MPTitledProtocol, NSPasteboardWriting, NSPasteboardReading>

/** The database controller which this MPRootSection is associated with. */
@property (readonly, weak, nullable) __kindof MPDatabasePackageController *packageController;

/** Creates a new MPRootSection. MPRootSection is abstract, do not allocate them but its subclasses.
 @param packageController The database with which to associate the root section with. */
- (nonnull instancetype)initWithPackageController:(nonnull MPDatabasePackageController *)packageController;

/** The objects the section represents in the data model. This is synonymous to -children, though subclasses can override if the items presented in a tree for the object (-children) should not correspond to the objects presented for the object when viewed in detail (-representedObjects). */
@property (readonly, strong, nonnull) NSArray *representedObjects;

/** The class name of a MPRootSection subclass determines the managed object class it's responsible for.
 @return For MPContributorRootSection, +managedObjectClass returns [MPContributor class]. */
+ (nonnull Class)managedObjectClass;

@property (readonly, strong, nonnull) NSImage *thumbnailImage;

/** The type of objects this root section represents, e.g. MPFigureRootSection => MPFigure */
@property (readonly, strong, nonnull) Class representedObjectClass;

/** Returns a root section given its referable dictionary representation (for instance created onto the pasteboard). */
+ (nullable id)objectWithReferableDictionaryRepresentation:(nonnull NSDictionary *)referableDictionaryRep;

@end