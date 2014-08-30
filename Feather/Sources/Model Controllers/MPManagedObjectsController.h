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

#import <CouchbaseLite/CouchbaseLite.h>

extern NSString * const MPManagedObjectsControllerErrorDomain;

/** A notification that is posted with the objects controller as the object whenever bundled resources have been finished loading. */
extern NSString * const MPManagedObjectsControllerLoadedBundledResourcesNotification;

typedef enum MPManagedObjectsControllerErrorCode
{
    MPManagedObjectsControllerErrorCodeUnknown = 0,
    MPManagedObjectsControllerErrorCodeInvalidJSON = 1
} MPManagedObjectsControllerErrorCode;

@class MPDatabase;
@class MPManagedObject;
@class MPDatabasePackageController;

@class CBLQuery;
@class CBLQueryEnumerator;

/** An abstract base class for controllers of MPManagedObject instances. 
 * - Caches managed objects strongly.
 * - allows querying and creating new managed objects of a certain type
 * - deserialises managed objects from their JSON representation
 * - resolves conflicting managed object revision arising from replication. 
 *
 * A MPManagedObjectsController subclass is parameterised by a managed object class 
 * (specified with the abstract method +managedObjectClass). 
 * Commonly it would also overload -configureViews: to introduce database views used by its database queries.
 *
 * The primary role of a managed objects controller is to act as a repository its managed objects.
 * To allow for fetching from the repository by using a a scripting command 'search', please
 * follow a convention of using the following method names for object fetching methods which return ordered collections of managed objects:
 * - -objectsWith<property>:
 * - <managed object plural>For<property>:
 * - <managed object plural>With<property>:
 * - <managed object plural>By<property>:
 *
 * Database fetches which return a single managed object object, please follow the method naming convention:
 * -objectFor<Property>:
 * -objectWith<Property>:
 * -objectBy<Property>:
 * */
@interface MPManagedObjectsController : NSObject <MPCacheable, MPManagedObjectRecentChangeObserver>

/** The MPDatabase whose objects this controller manages (not necessarily all of the objects in the database, just those with a matching class / objectType field).  */
@property (readonly, strong) MPDatabase *db;

/** A weak backpointer to the database package controller of this object (the database controller is a subclass of MPDatabasePackageController). */
@property (readonly, weak) id packageController;

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
- (BOOL)managesDocumentWithDictionary:(NSDictionary *)CBLDocumentDict;

- (BOOL)managesObjectsOfClass:(Class)class;

/** @return A map block emitting [_id, nil] for all documents managed by the controller. */
- (CBLMapBlock)allObjectsBlock;

/** @return a TDMapBlock emitting [_id, nil]
  * for all documents managed by the controller with bundled = YES. */
- (CBLMapBlock)bundledObjectsBlock;

/** A utility instance method which returns the same value as +managedObjectClassName. Not to be overloaded. */
- (NSString *)managedObjectClassName;

/** An array of managed object subclasses (array of Class objects). Loaded lazily, once during the application runtime. Can be called manually but should not be overloaded. */
+ (NSArray *)managedObjectClasses;

/** An array of managed object subclass names (array of class name strings). Loaded lazily, once during the application runtime. Can be called manually but should not be overloaded. */
+ (NSArray *)managedObjectClassNames;

/** A dictionary of managed object Class objects with the managed object controller class as the key. Loaded lazily, once during the application runtime. Can be called manually but should not be overloaded. */
+ (NSDictionary *)managedObjectClassByControllerClassNameDictionary;

/** Resolve conflicts for all managed objects managed by this controller. Calls -resolveConflictingRevisionsForObject: for all objects managed by this controller. */
- (BOOL)resolveConflictingRevisions:(NSError **)err;

/** Resolve conflicts for the specified object
 * @param obj the MPManagedObject for which to resolve conflicts. Must be non-nil. */
- (BOOL)resolveConflictingRevisionsForObject:(MPManagedObject *)obj
                                       error:(NSError **)err;

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
 * @param db The database of whose objects this controller manages. Must be one of the databases of the database controller given as the first argument.
 * @param err An optional error pointer. */
- (instancetype)initWithPackageController:(MPDatabasePackageController *)packageController
                                 database:(MPDatabase *)db error:(NSError **)err;

/**
 * A callback fired after the hosting MPDatabasePackageController for a MPManagedObjectsController has finished initialising all its managed objects controller 
 * (you can run code dependent on other managed objects controller here).
 */
- (void)didInitialize;

/** Configure the design document of this controller. Can (and commonly is) overloaded by subclasses, but not to be called manually. */
- (void)configureViews __attribute__((objc_requires_super));

/** The name of the view which returns all objects managed by this controller. */
- (NSString *)allObjectsViewName;

/** A query which returns all objects managed by this controller. */
- (CBLQuery *)allObjectsQuery;

/** @return a map of managed objects by the keys they are values of in the query enumerator given as argument. */
- (NSDictionary *)managedObjectByKeyMapForQueryEnumerator:(CBLQueryEnumerator *)rows;

/** @return an array of managed objects contained in the query enumerator given as argument. */
- (NSArray *)managedObjectsForQueryEnumerator:(CBLQueryEnumerator *)rows;

- (void)viewNamed:(NSString *)name setMapBlock:(CBLMapBlock)block setReduceBlock:(CBLReduceBlock)reduceBlock version:(NSString *)version;

- (void)viewNamed:(NSString *)name setMapBlock:(CBLMapBlock)block version:(NSString *)version;

/** All objects managed by this controller. */
@property (readonly, strong) NSArray *allObjects;

@property (readonly, strong) NSArray *objects;

/** An optional resource name for a touchdb typed file in the app's Contents/Resources directory. If overridden with a non-nil value, the resource is loaded upon initialisation. */
@property (readonly, copy) NSString *bundledResourceDatabaseName;

- (id)objectWithIdentifier:(NSString *)identifier;

/** Loads objects from the contents of an array JSON field. Each record in this array is validated to be a serialized MPManagedObject.
  * @param url The URL to load the objects from.
  * @param err An error pointer. */
- (NSArray *)objectsFromContentsOfArrayJSONAtURL:(NSURL *)url error:(NSError **)err;

/** Load bundled objects from resource with specified name and extension from inside the application main bundle. If resource checksum matches already saved checksum, return preloadedObjects, otherwise save the objects from the file into DB and return them. */
- (NSArray *)loadBundledObjectsFromResource:(NSString *)resourceName
                              withExtension:(NSString *)extension
                           matchedToObjects:(NSArray *)preloadedObjects
                    dataChecksumMetadataKey:(NSString *)dataChecksumKey
                                      error:(NSError **)err;

@end

@interface CBLDocument (MPManagedObjectExtensions)
- (Class) managedObjectClass;
- (NSURL *)URL;
@end