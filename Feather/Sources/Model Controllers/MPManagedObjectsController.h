//
//  MPManagedObjectsController.h
//  Feather
//
//  Created by Matias Piipari on 16/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MPCacheable.h"
#import "NSNotificationCenter+MPManagedObjectExtensions.h"

@import CouchbaseLite;

extern NSString *_Nonnull const MPManagedObjectsControllerErrorDomain;

/** A notification that is posted with the objects controller as the object whenever bundled resources have been finished loading. */
extern NSString *_Nonnull const MPManagedObjectsControllerLoadedBundledResourcesNotification;

typedef enum MPManagedObjectsControllerErrorCode
{
    MPManagedObjectsControllerErrorCodeUnknown = 0,
    MPManagedObjectsControllerErrorCodeInvalidJSON = 1,
    MPManagedObjectsControllerErrorCodeFailedTempFileCreation = 2
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
@interface MPManagedObjectsController<__covariant T:MPManagedObject *> : NSObject <MPCacheable, MPManagedObjectRecentChangeObserver>

/** The MPDatabase whose objects this controller manages (not necessarily all of the objects in the database, just those with a matching class / objectType field).  */
@property (readonly, strong, nonnull) MPDatabase *db;

/** A weak backpointer to the database package controller of this object (the database controller is a subclass of MPDatabasePackageController). */
@property (readonly, weak, nullable) __kindof MPDatabasePackageController *packageController;

/** Returns YES if objects of the +managedObjectClass in this controller's database should be automatically saved upon changing. Overload in a subclass to provide autosaving upon change (default: NO). */
@property (readonly) BOOL autosavesObjects;

/** Returns YES if objects managed by this controller receive notifications for changes (default: YES). Note that you do not need to implement the -didAdd...:, -didUpdate...:, -didRemove...: methods for MPManagedObjectsController subclasses, those are created for you automatically. */
@property (readonly) BOOL observesManagedObjectChanges;

/** Returns the MPManagedObject subclass of which instances in this controller's MPDatabase are managed by this controller. The method can be overloaded in MPManagedObject subclasses (for instance for performance reasons), but does not have to be for MPManagedObjectsController subclasses whose managed object class [X] and the controller class name follow the convention where the controller's class name is [X]sController (e.g. MPFeatherController and MPManuscript). 
 * @return The MPManagedObject subclass of which instances in this controller's MPDatabase are managed by this controller. */
+ (nonnull Class)managedObjectClass;

/** A utility method which returns the class name string for this controller's +managedObjectClass. */
+ (nonnull NSString *)managedObjectClassName;

/** Camel cased singular form of the managed object type, used for property naming. */
+ (nonnull NSString *)managedObjectSingular;

/** Camel cased plural form of the managed object type, used for property naming. */
+ (nonnull NSString *)managedObjectPlural;

/** A utility instance method which returns the same value as +managedObjectClass. Not to be overloaded. */
- (nonnull Class)managedObjectClass;

/** The set of managed object subclasses this managed objects controller can control. */
- (nonnull NSSet<NSString *> *)managedObjectSubclasses;

/** A utility for view functions which emit only for document dictionaries corresponding to
  * this controller's managed object subclasses. Subclasses can overload this method to filter objects 
  * emitted by view functions further (filtering an object out means returning `NO`). Subclass implementation 
  * of this method should never return `YES` for an object for which the MPManagedObjectsController 
  * base class implementation would return `NO` (results in undefined behaviour).
  * @return YES if document is managed by self, NO if not. 
  * There should not be multiple MPManagedObjectsControllers returning YES for any given document dictionary. */
- (BOOL)managesDocumentWithDictionary:(nonnull NSDictionary *)CBLDocumentDict;

/** A utility for view functions which emit only for documents corresponding to this controller's managed object subclasses.
  * See -managesDocumentWithDictionary: for more detail. */
- (BOOL)managesDocumentWithIdentifier:(nonnull NSString *)documentID;

- (BOOL)managesObjectsOfClass:(nonnull Class)class;

/** @return A map block emitting [_id, nil] for all documents managed by the controller. */
- (nonnull CBLMapBlock)allObjectsBlock;

/** @return a TDMapBlock emitting [_id, nil]
  * for all documents managed by the controller with bundled = YES. */
- (nonnull CBLMapBlock)bundledObjectsBlock;

/** A utility instance method which returns the same value as +managedObjectClassName. Not to be overloaded. */
- (nonnull NSString *)managedObjectClassName;

/** An array of managed object subclasses (array of Class objects). Loaded lazily, once during the application runtime. Can be called manually but should not be overloaded. */
+ (nonnull NSArray<Class> *)managedObjectClasses;

/** An array of managed object subclass names (array of class name strings). Loaded lazily, once during the application runtime. Can be called manually but should not be overloaded. */
+ (nonnull NSArray<NSString *>*)managedObjectClassNames;

/** A dictionary of managed object Class objects with the managed object controller class as the key. Loaded lazily, once during the application runtime. Can be called manually but should not be overloaded. */
+ (nonnull NSDictionary *)managedObjectClassByControllerClassNameDictionary;

/** Resolve conflicts for all managed objects managed by this controller. Calls -resolveConflictingRevisionsForObject: for all objects managed by this controller. */
- (BOOL)resolveConflictingRevisions:(out NSError *__autoreleasing __nonnull *__nonnull)err;

/** Resolve conflicts for the specified object
 * @param obj the MPManagedObject for which to resolve conflicts. Must be non-nil. */
- (BOOL)resolveConflictingRevisionsForObject:(nonnull MPManagedObject *)obj
                                       error:(out NSError *__autoreleasing __nonnull *__nonnull)err;

/** The base class of objects that are acceptable as a prototype. By default forwards to managedObjectClass. */
- (nonnull Class)prototypeClass;

#pragma mark -
#pragma mark Managed Object CRUD

/** Returns a new managed object. */
- (nonnull T)newObject;

/** Returns a new managed object with the specified prototype. */
- (nonnull T)newObjectWithPrototype:(nonnull MPManagedObject *)prototype;

/** Objects derived from the specified prototype ID */
- (nonnull NSArray<T> *)objectsWithPrototypeID:(nonnull NSString *)prototypeID;

/** Initializes a MPManagedObjectsController. Not to be called directly on MPManagedObjectsController (an abstract class). Initialization calls -registerManagedObjectsController: on the database controller with self given as the argument.
 * @param packageController The database controller which is to own this managed objects controller.
 * @param db The database of whose objects this controller manages. Must be one of the databases of the database controller given as the first argument.
 * @param err An optional error pointer. */
- (nonnull instancetype)initWithPackageController:(nonnull MPDatabasePackageController *)packageController database:(nonnull MPDatabase *)db error:(NSError *__autoreleasing __nonnull *__nonnull)err;

- (nonnull instancetype)init NS_UNAVAILABLE;

/** A callback fired after the hosting MPDatabasePackageController for a MPManagedObjectsController has finished initialising all its managed objects controller
  * (you can run code dependent on other managed objects controller here). */
- (BOOL)didInitialize:(NSError *__autoreleasing __nonnull *__nonnull)err;

/** Configure the design document of this controller. Can (and commonly is) overloaded by subclasses, but not to be called manually. */
- (void)configureViews __attribute__((objc_requires_super));

/** The name of the view which returns all objects managed by this controller. */
- (nonnull NSString *)allObjectsViewName;

/** A query which returns all objects managed by this controller. */
- (nonnull CBLQuery *)allObjectsQuery;

/** @return a map of managed objects by the keys they are values of in the query enumerator given as argument. */
- (nonnull NSDictionary<id, MPManagedObject *>*)managedObjectByKeyMapForQueryEnumerator:(nonnull CBLQueryEnumerator *)rows;

/** @return an array of managed objects contained in the query enumerator given as argument. */
- (nonnull NSArray *)managedObjectsForQueryEnumerator:(nonnull CBLQueryEnumerator *)rows;

- (void)viewNamed:(nonnull NSString *)name setMapBlock:(nonnull CBLMapBlock)block setReduceBlock:(nullable CBLReduceBlock)reduceBlock version:(nonnull NSString *)version;

- (void)viewNamed:(nonnull NSString *)name setMapBlock:(nonnull CBLMapBlock)block version:(nonnull NSString *)version;

/** All objects managed by this controller. */
@property (readonly, strong, nonnull) NSArray<T> *allObjects;

/** All objects managed by this controller, queried without wrapping to mp_dispatch_sync, and allowing for an error pointer. */
- (nonnull NSArray<T> *)allObjects:(NSError *__nonnull *__nonnull)error;

@property (readonly, strong, nonnull) NSArray<T> *objects;

/** An optional resource name for a touchdb typed file in the app's Contents/Resources directory. If overridden with a non-nil value, the resource is loaded upon initialisation. */
@property (readonly, copy, nonnull) NSString *bundledResourceDatabaseName;

@property (readonly) BOOL hasBundledResourceDatabase;

@property (readonly) BOOL hasBundledJSONData;

/** Bundled JSON data checksum key. */
@property (readonly, nullable) NSString *bundledJSONDataChecksumKey;

/** YES if hasBundledResourceDatabase or hasBundledJSONData returns YES. */
@property (readonly) BOOL requiresBundledDataLoading;

/** A query that should find all the bundled data that applies for this controller. */
@property (readonly, strong, nullable) CBLQuery *bundledJSONDataQuery;

/** Filename for a bundled JSON datafile that is loaded by the controller upon initialization. */
@property (readonly, strong, nullable) NSString *bundledJSONDataFilename;

/** The bundled resource file extension. By default ".json", can be overridden in subclasses. */
@property (readonly, strong, nullable) NSString *bundledResourceExtension;

/** Bundled JSON data derived objects. */
@property (readonly, nullable) NSArray<T> *bundledJSONDerivedData;

/** Gets an object managed by this managed objects controller from its cache, or from database, 
  * or in case it's not part of the shared package, 
  * from the shared package controller's database from its corresponding managed objects controller if one exists. */
- (nullable T)objectWithIdentifier:(nonnull NSString *)identifier;

/** Gets a document by documentID, allowing for depending on the allDocsMode argument for already deleted objects to be returned. */
- (nullable CBLDocument *)documentWithIdentifier:(nonnull NSString *)identifier allDocsMode:(CBLAllDocsMode)allDocsMode;

/** Whether the controller relays a search for an object to the shared package controller
  * if no match was found in an identifier search. 
  * Default NO, can be implemented in subclasses. */
@property (readonly) BOOL relaysFetchingByIdentifier;

/** Objects with the given 'title' field value (meaningless for objects with no title field) */
- (nonnull NSArray<T> *)objectsWithTitle:(nonnull NSString *)title;

/** Loads objects from the contents of an array JSON field. Each record in this array is validated to be a serialized MPManagedObject.
  * @param url The URL to load the objects from.
  * @param err An error pointer. */
- (nullable NSArray<T> *)objectsFromContentsOfArrayJSONAtURL:(nonnull NSURL *)url error:(NSError *__nullable *__nullable)err;

/** Loads objects from JSON data. Each record in the array is validated to be a serialized MPManagedObject. */
- (nullable NSArray<T> *)objectsFromArrayJSONData:(nonnull NSData *)objData error:(NSError *__autoreleasing __nullable * __nullable)err;

/** Objects from JSON encodable object array. */
- (nullable NSArray<T> *)objectsFromJSONEncodableObjectArray:(nonnull NSArray *)objs error:(NSError *__nonnull *__nonnull)err;

/** Loads a managed object from a JSON dictionary. Record is validated to be a serialized MPManagedObject. */
- (nullable T)objectFromJSONDictionary:(nonnull NSDictionary *)d isExisting:(BOOL *__nullable)isExisting error:(NSError *__nullable *__nullable)err;

/** Load bundled objects from resource with specified name and extension from inside the application main bundle. If resource checksum matches already saved checksum, return preloadedObjects, otherwise save the objects from the file into DB and return them. */
- (nullable NSArray<T> *)loadBundledObjectsFromResource:(nonnull NSString *)resourceName
                                withExtension:(nonnull NSString *)extension
                           matchedToObjects:(nonnull NSArray *)preloadedObjects
                    dataChecksumMetadataKey:(nonnull NSString *)dataChecksumKey
                                      error:(NSError *__nullable *__nullable)err;

/** Query the given view with the given keys, with object prefetching enabled, and return managed object representations. */
- (nonnull NSArray<T> *)objectsMatchingQueriedView:(nonnull NSString *)view keys:(nullable NSArray *)keys;

@end

@interface CBLDocument (MPManagedObjectExtensions)
- (nonnull Class) managedObjectClass;
- (nullable NSURL *)URL;
@end