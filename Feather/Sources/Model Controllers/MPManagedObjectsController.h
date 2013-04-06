//
//  MPManagedObjectsController.h
//  Feather
//
//  Created by Matias Piipari on 16/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MPCacheable.h"
#import "NSNotificationCenter+MPExtensions.h"

#import <TouchDB/TouchDB.h>
#import <CouchCocoa/CouchDocument.h>

extern NSString * const MPManagedObjectsControllerErrorDomain;

typedef enum MPManagedObjectsControllerErrorCode
{
    MPManagedObjectsControllerErrorCodeUnknown = 0,
    MPManagedObjectsControllerErrorCodeInvalidJSON = 1
} MPManagedObjectsControllerErrorCode;

@class MPDatabase;
@class MPManagedObject;
@class MPDatabasePackageController;

@class RESTOperation;
@class CouchDesignDocument;
@class CouchQuery;
@class CouchQueryEnumerator;

/** An abstract base class for controllers of MPManagedObject instances. Caches managed objects strongly, allows querying and creating new Feather of a certain type, loading them from a JSON file, and resolving conflicting versions arising from replication. A MPManagedObjectsController subclass is parameterised by a managed object class (specified with the abstract method +managedObjectClass). Commonly it would also overload -configureDesignDocument: and -allObjectsQuery. */
@interface MPManagedObjectsController : NSObject <MPCacheable, MPManagedObjectRecentChangeObserver>

/** The MPDatabase whose objects this controller manages (not necessarily all of the objects in the database, just those with a matching class / objectType field).  */
@property (readonly, strong) MPDatabase *db;

/** A weak backpointer to the database package controller of this object (the database controller is a subclass of MPDatabasePackageController). */
@property (readonly, weak) id packageController;

/** A CouchDesignDocument for this controller. Note that for TouchDB databases the CouchDesignDocument is practically empty: the validation and view functions are set during runtime.  */
@property (readonly, strong) CouchDesignDocument *designDocument;

/** Returns YES if objects of the +managedObjectClass in this controller's database should be automatically saved upon changing. Overload in a subclass to provide autosaving upon change (default: NO). */
@property (readonly) BOOL autosavesObjects;

/** Returns YES if objects managed by this controller receive notifications for changes (default: YES). Note that you do not need to implement the -didAdd...:, -didUpdate...:, -didRemove...: methods for MPManagedObjectsController subclasses, those are created for you automatically. */
@property (readonly) BOOL observesManagedObjectChanges;

/** Returns the MPManagedObject subclass of which instances in this controller's MPDatabase are managed by this controller. The method can be overloaded in MPManagedObject subclasses (for instance for performance reasons), but does not have to be for MPManagedObjectsController subclasses whose managed object class [X] and the controller class name follow the convention where the controller's class name is [X]sController (e.g. MPFeatherController and MPManuscript). 
 * @return The MPManagedObject subclass of which instances in this controller's MPDatabase are managed by this controller. */
+ (Class)managedObjectClass;

/** A utility method which returns the class name string for this controller's +managedObjectClass. */
+ (NSString *)managedObjectClassName;

/** A utility instance method which returns the same value as +managedObjectClass. Not to be overloaded. */
- (Class)managedObjectClass;

/** The set of managed object subclasses this managed objects controller can control. */
- (NSSet *)managedObjectSubclasses;

/** A utility for view functions which emit only for document dictionaries corresponding to
  * this controller's managed object subclasses. Subclasses can overload this method to filter objects 
  * emitted by view functions further (filtering an object out means returning `NO`). Subclass implementation 
  * of this method should never return `YES` for an object for which the MPManagedObjectsController 
  * base class implementation would return `NO` (results in undefined behaviour).
  * @return YES if document is managed by self, NO if not. 
  * There should not be multiple MPManagedObjectsControllers returning YES for any given document dictionary. */
- (BOOL)managesDocumentWithDictionary:(NSDictionary *)couchDocumentDict;

/** @return A map block emitting [_id, nil] for all documents managed by the controller. */
- (TDMapBlock)allObjectsBlock;

/** @return a TDMapBlock emitting [_id, nil]
  * for all documents managed by the controller with bundled = YES. */
- (TDMapBlock)bundledObjectsBlock;

/** A utility instance method which returns the same value as +managedObjectClassName. Not to be overloaded. */
- (NSString *)managedObjectClassName;

/** An array of managed object subclasses (array of Class objects). Loaded lazily, once during the application runtime. Can be called manually but should not be overloaded. */
+ (NSArray *)managedObjectClasses;

/** An array of managed object subclass names (array of class name strings). Loaded lazily, once during the application runtime. Can be called manually but should not be overloaded. */
+ (NSArray *)managedObjectClassNames;

/** A dictionary of managed object Class objects with the managed object controller class as the key. Loaded lazily, once during the application runtime. Can be called manually but should not be overloaded. */
+ (NSDictionary *)managedObjectClassByControllerClassNameDictionary;

/** Resolve conflicts for all managed objects managed by this controller. Calls -resolveConflictingRevisionsForObject: for all objects managed by this controller. */
- (void)resolveConflictingRevisions;

/** Resolve conflicts for the specified object
 * @param obj the MPManagedObject for which to resolve conflicts. Must be non-nil. */
- (void)resolveConflictingRevisionsForObject:(MPManagedObject *)obj;

/** Prototype (for some object types called the "template") for an object. Created on demand if not present and should be. */
- (MPManagedObject *)prototypeForObject:(MPManagedObject *)object;

#pragma mark -
#pragma mark Managed Object CRUD

/** Returns a new managed object. */
- (id)newObject;

/** Returns a new managed object with the specified prototype. */
- (id)newObjectWithPrototype:(MPManagedObject *)prototype;

/** */
- (NSArray *)objectsWithPrototypeID:(NSString *)prototypeID;

/** Initializes a MPManagedObjectsController. Not to be called directly on MPManagedObjectsController (an abstract class). Initialization calls -registerManagedObjectsController: on the database controller with self given as the argument.
 * @param packageController The database controller which is to own this managed objects controller.
 * @param db The database of whose objects this controller manages. Must be one of the databases of the database controller given as the first argument. */
- (instancetype)initWithPackageController:(MPDatabasePackageController *)packageController database:(MPDatabase *)db;

/** Configure the design document of this controller. Can (and commonly is) overloaded by subclasses, but not to be called manually.
  * @param designDoc The design document for this managed objects controller. */
- (void)configureDesignDocument:(CouchDesignDocument *)designDoc;

/** The name of the view which returns all objects managed by this controller. */
- (NSString *)allObjectsViewName;

/** A query which returns all objects managed by this controller. */
- (CouchQuery *)allObjectsQuery;

- (NSArray *)managedObjectsForQueryEnumerator:(CouchQueryEnumerator *)rows;

/** All objects managed by this controller. */
@property (readonly, strong) NSArray *allObjects;

- (void)loadBundledResources;

- (id)objectWithIdentifier:(NSString *)identifier;

/** Loads objects from the contents of an array JSON field. Each record in this array is validated to be a serialized MPManagedObject.
  * @param url The URL to load the objects from.
  * @param err An error pointer. */
- (NSArray *)objectsFromContentsOfArrayJSONAtURL:(NSURL *)url error:(NSError **)err;

/** Load bundled objects from resource with specified name and extension from inside the application main bundle. If resource checksum matches already saved checksum, return preloadedObjects, otherwise save the objects from the file into DB and return them. */
- (NSArray *)loadBundledObjectsFromResource:(NSString *)resourceName
                          withExtension:(NSString *)extension
                       matchedToObjects:(NSArray *)preloadedObjects
                dataChecksumMetadataKey:(NSString *)dataChecksumKey;

@end


@interface CouchDocument (MPManagedObjectExtensions)
- (Class) managedObjectClass;
@end