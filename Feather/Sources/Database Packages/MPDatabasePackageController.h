//
//  MPDatabasePackageController.h
//  Feather
//
//  Created by Matias Piipari on 23/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPContributorsController.h"

#import <CouchbaseLite/CouchbaseLite.h>

typedef void (^MPPullCompletionHandler)(NSDictionary *errDict);

@class MPDatabase, MPSnapshot;
@class CBLDocument;

@class MPSearchIndexController;

/** A delegate protocol for MPDatabasePackageController's optional delegate. */
@protocol MPDatabasePackageControllerDelegate <NSObject>
@property (readonly, strong) NSURL *packageRootURL;
@optional
- (void)updateChangeCount:(NSDocumentChangeType)changeType; // pass back document change notifications upon db changes.
@end

extern NSString * const MPDatabasePackageControllerErrorDomain;

typedef enum MPDatabasePackageControllerErrorCode
{
    MPDatabasePackageControllerErrorCodeUnknown = 0,
    MPDatabasePackageControllerErrorCodeNoSuchSnapshot = 1,
    MPDatabasePackageControllerErrorCodeUnexpectedResponse = 2,
    MPDatabasePackageControllerErrorCodeFileNotDirectory = 3,
    MPDatabasePackageControllerErrorCodeDirectoryAlreadyExists = 4,
    MPDatabasePackageControllerErrorCodeCannotInitializeSharedDatabases = 5
} MPDatabasePackageControllerErrorCode;


@class CouchServer;
@class MPManagedObjectsController, MPSnapshotsController, MPDatabase;

/** A MPDatabasePackageController manages a number of MPDatabase objects and MPManagedObjectsController, which in turn manage the MPManagedObject instances stored in the databases. The databases owned by a MPDatabasePackageController can be replicated with a remote CouchDB server. All of the databases of a MPDatabasePackageController are stored on the same CouchServer, also owned by the MPDatabasePackageController. This combination of databases under a shared server (either a shared filesystem root directory in the case of TouchDB, or a base URI in a remote CouchDB server) is called a _database package_.
 *
 * In Feather.app, MPDatabasePackageController's subclass MPFeatherPackageController is the controller which the NSDocument subclass MPDocument relies on for reading and writing Feather document packages. There is however no dependence on Feather or a document based design in MPDatabasePackageController. It is intended to be crossplatform. */
@interface MPDatabasePackageController : NSObject <CBLViewCompiler, NSNetServiceDelegate, NSNetServiceBrowserDelegate>

/** The filesystem path of the database package. */
@property (strong, readonly) NSString *path;

/** The database server for this database package. */
@property (strong, readonly) CBLManager *server;

@property (readonly) NSUInteger serverQueueToken;

/** The base remote URL for the document package. NOTE! An abstract method. */
@property (strong, readonly) NSURL *remoteURL;

/** The base remote URL for the document package's backing web service. NOTE! An abstract method. */
@property (strong, readonly) NSURL *remoteServiceURL;

/** Returns YES if the package's databases should be synced with databases available at remoteURL. Subclass must implement the syncing in response to synchronizesWithRemote = YES. (default: YES). */
@property (readonly) BOOL synchronizesWithRemote;

/** If returns YES, package's snapshot databases should be synced (default: NO). */
@property (readonly) BOOL synchronizesSnapshots;

/** If returns YES, package's databases should be synced peerlessly (default: YES, overridable application wide with user default MPDefaultsKeySyncPeerlessly). */
@property (readonly) BOOL synchronizesPeerlessly;

@property (readonly, strong) NSURL *databaseListenerURL;
@property (readonly) NSUInteger databaseListenerPort;

/** Indicates whether the database package controller's contents are to be full text indexed. 
  * Default implementation returns NO, overload to toggle on full-text indexing (see also MPManagedObject FTS indexing related properties and methods.) */
@property (readonly) BOOL indexesObjectFullTextContents;

/** @return A file URL to the root directory of a temporary copy of the package. */
- (BOOL)makeTemporaryCopyIntoRootDirectoryWithURL:(NSURL *)rootURL
                                overwriteIfExists:(BOOL)overwrite
                                     failIfExists:(BOOL)failIfExists
                                            error:(NSError **)error;

/** 
 * Initializes a database package controller at a given path, with an optional delegate and error pointer.
 * @param path The filesystem path for the root directory of the database pacakge.
 * @param delegate An optional delegate.
 * @param err An error pointer.
 * */
- (instancetype)initWithPath:(NSString *)path
                    readOnly:(BOOL)readOnly
                    delegate:(id<MPDatabasePackageControllerDelegate>)delegate
                       error:(NSError *__autoreleasing *)err;

/** Closes all the database package's databases. */
- (void)close;

/** @return the controller for a MPManagedObject subclass.
 @param class A subclass of MPManagedObject. */
- (MPManagedObjectsController *)controllerForManagedObjectClass:(Class)class;

/** The managed object controller subclass closes in the class hierarchy to the managed object class.
  * For instance, for a MPManagedObject > MPColor > MPRGBColor hierarchy, if there is no
  * MPRGBColorsController in the controller class hierarchy, but there is a MPColorsController, 
  * will return MPColorsController.
  */
+ (Class)controllerClassForManagedObjectClass:(Class)class;

/** @return YES if a controller exists in this package controller for a managed object class. */
- (BOOL)controllerExistsForManagedObjectClass:(Class)class;

/** Return the controller for a CBLDocument object, based on its database and the document's objectType property.
 * @param document A CBLDocument containing a serialised MPManagedObject (including a key 'objectType' whose value matches the name of one of the MPManagedObject subclasses). */
- (MPManagedObjectsController *)controllerForDocument:(CBLDocument *)document;

/** The remote base URL for a local MPDatabase object.
  * @param database A local MPDatabase. */
- (NSURL *)remoteDatabaseURLForLocalDatabase:(MPDatabase *)database;

/** The remote service URL for a local MPDatabase object. 
  * @param database A local MPDatabase. */
- (NSURL *)remoteServiceURLForLocalDatabase:(MPDatabase *)database;

/** The remote database login credentails for a local MPDatabase object.
 * @param database A local MPDatabase. */
- (NSURLCredential *)remoteDatabaseCredentialsForLocalDatabase:(MPDatabase *)database;

/** Absolute remote URLs for database of
 * @param baseURL The remote base URL for which to return the database URLs. */
+ (NSArray *)databaseURLsForBaseURI:(NSURL *)baseURL;

/** Push asynchronously to a remote database package.
 * @param errorDict A dictionary of errors for *starting* replications (i.e. there can be errors during the asynchronous replication that are not captured here), keys being database names. 
 **/
- (BOOL)pushToRemoteWithErrorDictionary:(NSDictionary **)errorDict;

/** Pull asynchronously from a remote database package.
 * @param errorDict A dictionary of errors for *starting* replications (i.e. there can be errors during the asynchronous replication that are not captured here), keys being database names. 
 **/
- (void)pullFromRemoteWithErrorDictionary:(NSDictionary **)errorDict;

/** Pull and push asynchronously to a remote database package.
   * @param errorDict A dictionary of errors for *starting* replications (i.e. there can be errors during the asynchronous replication that are not captured here), keys being database names. */
- (BOOL)syncWithRemote:(NSDictionary **)errorDict;

/** Name for the push filter function used for the given database. Nil return value means that no push filter is to be used. Default implementation uses no push filter. If this method returns nil for a given db, the subclass must implement -create */
- (NSString *)pushFilterNameForDatabaseNamed:(NSString *)db;

/** @param url The remote database URL with which content to this database is to be pulled from.
  * @param database The database to pull to. One of the databases managed by this object.
  * @return Return value indicates if the filter with the name pullFilterName should be added when pulling from the remote. Default implementation returns YES always. */
- (BOOL)applyFilterWhenPullingFromDatabaseAtURL:(NSURL *)url toDatabase:(MPDatabase *)database;

/** @param The remote database URL with which content to this database is to be pushed to.
  * @param database The database to push from. One of the databases managed by this object.
  * @return Return value indicates if the filter with the name pushFilterName should be added when pulling from the remote. Default implementation returns YES always. */
- (BOOL)applyFilterWhenPushingToDatabaseAtURL:(NSURL *)url fromDatabase:(MPDatabase *)database;

/** Returns a new filter block with the given name to act as a push filter for the specified database.
 * Overloadable by subclasses, but not intended to be called manually. Gets called if -pushFilterNameForDatabaseNamed: returns a non-nil filter name for a db. If filterName is non-nil, *must* return a non-nil value. */
- (CBLFilterBlock)createPushFilterBlockWithName:(NSString *)filterName forDatabase:(MPDatabase *)db;

/** Name of the pull filter for the given database. Nil return value means that no pull filter is to be used. Default implementation uses no push filter. */
- (NSString *)pullFilterNameForDatabaseNamed:(NSString *)dbName;

@property (readonly) NSTimeInterval syncTimerPeriod;

/** The managed objects controllers. When one is created in a subclass, make sure to call -registerManagedObjectsController: for it */
@property (strong, readonly) NSSet *managedObjectsControllers;

/** The MPDatabase objects for this database package. Note that multiple MPManagedObjectsController objects can manage objects in a MPDatabase. */
@property (strong, readonly) NSSet *databases;

/** A utility method which returns the names of the databases for this package. As database names are unique per database package, this will match. */
@property (strong, readonly) NSSet *databaseNames;

/** */
@property (strong, readonly) MPContributorsController *contributorsController;

/** A set of database names. Subclasses should overload this if they wish to include databases additional to the 'snapshots' database created by the abstract base class MPDatabasePackageController. Overloaded method _must_ include the super class -databaseNames in the set of database names returned. Databases are created automatically upon initialization based on the names determined here. */
+ (NSSet *)databaseNames;

/** Returns the name of the primary database in this package, used to store essential information such as contributors and a metadata record. NOTE! Abstract method: must be overloaded by subclass to provide the name for the primary database (for Feather this is 'manuscript'). If nil, there is no primary database to be created by the package controller. */
+(NSString *)primaryDatabaseName;

/** Returns a database with a given name. Should by only called with names from the set +databaseNames. */
- (MPDatabase *)databaseWithName:(NSString *)name;

/** A globally unique identifier for the database controller. Must be overloaded by a subclass. */
@property (strong, readonly) NSString *identifier;

/** An optional delegate for the database package controller. */
@property (weak) id<MPDatabasePackageControllerDelegate> delegate;

/** The notification center to which notifications about objects of this database package post notifications to.
  * The default implementation returns [NSNotificationCenter defaultCenter], but the subclass
  * (for instance a database package controller used to back a NSDocument) can provide its own. */
@property (strong, readonly) NSNotificationCenter *notificationCenter;

/** The snapshot controller. */
@property (strong, readonly) MPSnapshotsController *snapshotsController;

/** Create and persist a snapshot of this package.
  * @param name A name for the snapshot. Must be non-nil, but not necessarily unique.
  * @param An optional error pointer. */
- (MPSnapshot *)newSnapshotWithName:(NSString *)name error:(NSError **)err;

/** Restore the state of the database package using a named snapshot.
 * @param name The name of the snapshot to restore the state for the package from.
 * @param err An error pointer. */
- (BOOL)restoreFromSnapshotWithName:(NSString *)name error:(NSError **)err;


@property (strong, readonly) NSArray *rootSections;
@property (strong, readonly) NSArray *nonEmptyRootSections;
@property (strong, readonly) NSArray *outlinerRootSections;

/** Root section class names ordered in the priority order needed. */
+ (NSArray *)orderedRootSectionClassNames;

@end

