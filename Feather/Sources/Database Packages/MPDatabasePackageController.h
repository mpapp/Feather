//
//  MPDatabasePackageController.h
//  Feather
//
//  Created by Matias Piipari on 23/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Foundation;

@import CouchbaseLite;

typedef void (^MPPullCompletionHandler)(NSDictionary * __nullable errDict);

@class MPDatabase, MPSnapshot, MPDraft;
@class CBLDocument;
@class MPContributorsController, MPContributorIdentitiesController;
@class TreeItemPool;
@class MPDatabasePackageController;
@class MPManagedObject;
@class CloudKitSyncService;

@class MPSearchIndexController;

/** 
 * A notification that's fired once the database package listener is ready to be used at a port.
 */
extern NSString *_Nonnull const MPDatabasePackageListenerDidStartNotification;

/** A delegate protocol for MPDatabasePackageController's optional delegate. */
@protocol MPDatabasePackageControllerDelegate <NSObject>

/** Returns nil when package is yet to be saved. */
@property (readonly, strong, nullable) NSURL *packageRootURL;
@optional

/** Callback used to send back document change notifications upon db changes. */
- (void)updateChangeCount:(NSDocumentChangeType)changeType;

/** If callback is not implemented, listener is added. 
  * If callback is implemented, YES return value causes a listener to be created, NO leads to it being omitted. 
  * 
  * Listener is by default not started for XPC services, 
 * command line tools and when the package controller has not been set to synchronize peerlessly (`-synchronizesPeerlessly`). */
- (BOOL)packageControllerRequiresListener:(nonnull MPDatabasePackageController *)packageController;

/** Return YES if you want to allow initialising the content of the package with some (for instance onboarding oriented) content.
  * If set to YES, ensurePlaceholderInitialized is called on it. */
- (BOOL)packageControllerRequiresPlaceholderContent:(nonnull MPDatabasePackageController *)packageController;

@end

extern NSString *_Nonnull const MPDatabasePackageControllerErrorDomain;

typedef enum MPDatabasePackageControllerErrorCode {
    MPDatabasePackageControllerErrorCodeUnknown = 0,
    MPDatabasePackageControllerErrorCodeNoSuchSnapshot = 1,
    MPDatabasePackageControllerErrorCodeUnexpectedResponse = 2,
    MPDatabasePackageControllerErrorCodeFileNotDirectory = 3,
    MPDatabasePackageControllerErrorCodeDirectoryAlreadyExists = 4,
    MPDatabasePackageControllerErrorCodeCannotInitializeSharedDatabases = 5,
    MPDatabasePackageControllerErrorCodeDictionaryRepresentationInvalid = 6,
    MPDatabasePackageControllerErrorCodeNoDatabases = 7,
    MPDatabasePackageControllerErrorCodeOngoingTransaction = 8
} MPDatabasePackageControllerErrorCode;


@class CouchServer;
@class MPManagedObjectsController, MPSnapshotsController, MPDatabase;
@class MPRootSection;
@class MPContributor, MPContributorIdentity;

/** A MPDatabasePackageController manages a number of MPDatabase objects and MPManagedObjectsController, which in turn manage the MPManagedObject instances stored in the databases. The databases owned by a MPDatabasePackageController can be replicated with a remote CouchDB server. All of the databases of a MPDatabasePackageController are stored on the same CouchServer, also owned by the MPDatabasePackageController. This combination of databases under a shared server (either a shared filesystem root directory in the case of TouchDB, or a base URI in a remote CouchDB server) is called a _database package_.
 *
 * In Feather.app, MPDatabasePackageController's subclass MPFeatherPackageController is the controller which the NSDocument subclass MPDocument relies on for reading and writing Feather document packages. There is however no dependence on Feather or a document based design in MPDatabasePackageController. It is intended to be crossplatform. */
@interface MPDatabasePackageController : NSObject <CBLViewCompiler, NSNetServiceDelegate, NSNetServiceBrowserDelegate>

/** The filesystem base path (= path to the the root) of the database package. */
@property (strong, readonly, nonnull) NSString *path;

- (nonnull NSString *)pathForDatabase:(nonnull MPDatabase *)database;

/** A file URL to the root of the database package. */
@property (strong, readonly, nonnull) NSURL *URL;

@property (readonly, nonnull) NSString *sessionID;

/** The database server for this database package. */
@property (strong, readonly, nonnull) CBLManager *server;

/** All objects in the database package's databases. No particular sort order is guaranteed. */
@property (readonly, nonnull) NSArray<__kindof MPManagedObject *> *allObjects;

@property (readonly) unsigned long long serverQueueToken;

/** The base remote URL for the document package. NOTE! An abstract method. */
@property (strong, readonly, nullable) NSURL *remoteURL;

/** The base remote URL for the document package's backing web service. NOTE! An abstract method. */
@property (strong, readonly, nullable) NSURL *remoteServiceURL;

/** Returns YES if the package's databases should be synced with databases available at remoteURL. Subclass must implement the syncing in response to synchronizesWithRemote = YES. (default: YES). */
@property (readonly) BOOL synchronizesWithRemote;

/** If returns YES, package's snapshot databases should be synced (default: NO). */
@property (readonly) BOOL synchronizesSnapshots;

@property (readonly) BOOL synchronizesUsingCloudKit;
@property (readonly, nullable) CloudKitSyncService *cloudKitSyncService;

/** If returns YES, package's databases should be synced peerlessly (default: YES, overridable application wide with user default MPDefaultsKeySyncPeerlessly). */
@property (readonly) BOOL synchronizesPeerlessly;

@property (readonly, strong, nullable) NSURL *databaseListenerURL;
@property (readonly) NSUInteger databaseListenerPort;

@property (readonly, nonnull) TreeItemPool *treeItemPool;

/** Indicates whether the database package controller's contents are to be full text indexed. 
  * Default implementation returns NO, overload to toggle on full-text indexing (see also MPManagedObject FTS indexing related properties and methods.) */
@property (readonly) BOOL indexesObjectFullTextContents;

/** List databases within the package that were determined to be corrupted during initialization, and hence were reset to an empty state.
    This is intended to give the owner of this database package controller the chance to restore database contents from a backup that is external to the database files.
 */
@property (readonly, nullable) NSArray<MPDatabase *> *databasesResetDuringInitialization;

/** @return A file URL to the root directory of a temporary copy of the package. */
- (BOOL)makeTemporaryCopyIntoRootDirectoryWithURL:(nonnull NSURL *)rootURL
                                overwriteIfExists:(BOOL)overwrite
                                     failIfExists:(BOOL)failIfExists
                                            error:(NSError *__nonnull *__nonnull)error;

/** 
 * Initializes a database package controller at a given path, with an optional delegate and error pointer.
 * @param path The filesystem path for the root directory of the database pacakge.
 * @param delegate An optional delegate.
 * @param err An error pointer.
 * */
- (nullable instancetype)initWithPath:(nonnull NSString *)path
                             readOnly:(BOOL)readOnly
                             delegate:(nullable id<MPDatabasePackageControllerDelegate>)delegate
                                error:(NSError *__nonnull __autoreleasing *__nonnull)err;

/** Closes all the database package's databases. */
- (BOOL)close:(NSError *_Nullable *_Nullable)error;

/** @return the controller for a MPManagedObject subclass.
 @param class A subclass of MPManagedObject. */
- (nullable __kindof MPManagedObjectsController *)controllerForManagedObjectClass:(nonnull Class)class;

/** The managed object controller subclass closes in the class hierarchy to the managed object class.
  * For instance, for a MPManagedObject > MPColor > MPRGBColor hierarchy, if there is no
  * MPRGBColorsController in the controller class hierarchy, but there is a MPColorsController, 
  * will return MPColorsController.
  */
+ (nullable Class)controllerClassForManagedObjectClass:(nonnull Class)class;

/** Get the property name for a MPManagedObject subclass. */
+ (nullable NSString *)controllerPropertyNameForManagedObjectClass:(nonnull Class)cls;

/** @return YES if a controller exists in this package controller for a managed object class. */
- (BOOL)controllerExistsForManagedObjectClass:(nonnull Class)class;

/** Gets the property name for the controller for objects of the MPManagedObject subclass given as an argument. */
+ (nullable NSString *)controllerPropertyNameForManagedObjectControllerClass:(nonnull Class)class;

/** Return the controller for a CBLDocument object, based on its database and the document's objectType property.
 * @param document A CBLDocument containing a serialised MPManagedObject (including a key 'objectType' whose value matches the name of one of the MPManagedObject subclasses). */
- (nonnull MPManagedObjectsController *)controllerForDocument:(nonnull CBLDocument *)document;

/** The remote base URL for a local MPDatabase object.
  * @param database A local MPDatabase. */
- (nonnull NSURL *)remoteDatabaseURLForLocalDatabase:(nonnull MPDatabase *)database;

/** The remote service URL for a local MPDatabase object. 
  * @param database A local MPDatabase. */
- (nonnull NSURL *)remoteServiceURLForLocalDatabase:(nonnull MPDatabase *)database;

/** The remote database login credentails for a local MPDatabase object.
 * @param database A local MPDatabase. */
- (nonnull NSURLCredential *)remoteDatabaseCredentialsForLocalDatabase:(nonnull MPDatabase *)database;

/** Absolute remote URLs for database of
 * @param baseURL The remote base URL for which to return the database URLs. */
+ (nonnull NSArray <NSURL *>*)databaseURLsForBaseURI:(nonnull NSURL *)baseURL;

/** Push asynchronously to a remote database package.
 * @param errorDict A dictionary of errors for *starting* replications (i.e. there can be errors during the asynchronous replication that are not captured here), keys being database names. 
 **/
- (BOOL)pushToRemoteWithErrorDictionary:(NSDictionary *__nullable *__nullable)errorDict;

/** Pull asynchronously from a remote database package.
 * @param errorDict A dictionary of errors for *starting* replications (i.e. there can be errors during the asynchronous replication that are not captured here), keys being database names. 
 **/
- (void)pullFromRemoteWithErrorDictionary:(NSDictionary<NSString *, NSError *> *__nullable *__nullable)errorDict;

/** Pulls from all the databases of the package at the specified file URL. 
  * Returns NO and an error if pulling failed to _start_ (errors may happen during the pull too). */
- (BOOL)pullFromPackageFileURL:(nonnull NSURL *)url error:(NSError *__nullable *__nullable)error;

/** Pull and push asynchronously to a remote database package.
   * @param errorDict A dictionary of errors for *starting* replications (i.e. there can be errors during the asynchronous replication that are not captured here), keys being database names. */
- (BOOL)syncWithRemote:(NSDictionary<NSString *, NSError *> *__nullable *__nullable)errorDict;

/** Compacts the manuscript's all databases. */
- (BOOL)compact:(NSError *__nullable *__nullable)error;

/** Name for the push filter function used for the given database. Nil return value means that no push filter is to be used. Default implementation uses no push filter. If this method returns nil for a given db, the subclass must implement -create */
- (nullable NSString *)pushFilterNameForDatabaseNamed:(nonnull NSString *)db;

/** @param url The remote database URL with which content to this database is to be pulled from.
  * @param database The database to pull to. One of the databases managed by this object.
  * @return Return value indicates if the filter with the name pullFilterName should be added when pulling from the remote. Default implementation returns YES always. */
- (BOOL)applyFilterWhenPullingFromDatabaseAtURL:(nonnull NSURL *)url toDatabase:(nonnull MPDatabase *)database;

/** @param The remote database URL with which content to this database is to be pushed to.
  * @param database The database to push from. One of the databases managed by this object.
  * @return Return value indicates if the filter with the name pushFilterName should be added when pulling from the remote. Default implementation returns YES always. */
- (BOOL)applyFilterWhenPushingToDatabaseAtURL:(nonnull NSURL *)url fromDatabase:(nonnull MPDatabase *)database;

/** Returns a new filter block with the given name to act as a push filter for the specified database.
 * Overloadable by subclasses, but not intended to be called manually. Gets called if -pushFilterNameForDatabaseNamed: returns a non-nil filter name for a db. If filterName is non-nil, *must* return a non-nil value. */
- (nonnull CBLFilterBlock)createPushFilterBlockWithName:(nonnull NSString *)filterName forDatabase:(nonnull MPDatabase *)db;

/** Name of the pull filter for the given database. Nil return value means that no pull filter is to be used. Default implementation uses no push filter. */
- (nullable NSString *)pullFilterNameForDatabaseNamed:(nonnull NSString *)dbName;

@property (readonly) NSTimeInterval syncTimerPeriod;

/** The managed objects controllers. When one is created in a subclass, make sure to call -registerManagedObjectsController: for it */
@property (strong, readonly, nonnull) NSSet<MPManagedObjectsController *> *managedObjectsControllers;

/** The MPDatabase objects for this database package. Note that multiple MPManagedObjectsController objects can manage objects in a MPDatabase. */
@property (strong, readonly, nonnull) NSSet<MPDatabase *> *databases;

@property (copy, readonly, nonnull) NSArray<MPDatabase *> *orderedDatabases;

/** A utility method which returns the names of the databases for this package. As database names are unique per database package, this will match. */
@property (strong, readonly, nonnull) NSSet<NSString *> *databaseNames;

/** A utility property to ease KVC access to databases by their name (e.g. for scripting). */
@property (copy, readonly, nonnull) NSDictionary<NSString *, MPDatabase *> *databasesByName;

/** Controller assigned to all MPContributor objects in the package. */
@property (strong, readonly, nonnull) MPContributorsController *contributorsController;

/** Controller assigned to all MPContributorIdentity objects in the package. */
@property (strong, readonly, nonnull) MPContributorIdentitiesController *contributorIdentitiesController;

/** A set of database names. Subclasses should overload this if they wish to include databases additional to the 'snapshots' database created by the abstract base class MPDatabasePackageController. Overloaded method _must_ include the super class -databaseNames in the set of database names returned. Databases are created automatically upon initialization based on the names determined here. */
+ (nonnull NSSet<NSString *>*)databaseNames;

/** Returns the name of the primary database in this package, used to store essential information such as contributors and a metadata record. NOTE! Abstract method: must be overloaded by subclass to provide the name for the primary database (for Feather this is 'manuscript'). If nil, there is no primary database to be created by the package controller. */
+(nullable NSString *)primaryDatabaseName;

/** Returns a database with a given name. Safe to be called only with names from the set +databaseNames. */
- (nonnull MPDatabase *)databaseWithName:(nonnull NSString *)name;

/** Returns a file URL to a database that is to be used as a basis for the data in the database with the specified name (bootstrap the data = copy data into shared database, then modify it there).
  * Base class implementation returns always nil, can be overridden in subclasses. */
- (nullable NSURL *)bootstrapDatabaseURLForDatabaseWithName:(nonnull NSString *)dbName;

/** A globally unique identifier for the database controller. Must be overloaded by a subclass. */
@property (strong, readonly, nonnull) NSString *identifier;

/** Signifies whether the package controller is identifiable. 
  * Base class implementation simply returns self.identifier != nil but you may want to override this for lazily populated identifiers (for instance if the identifier itself is based on the database state, the package controller may not always be identifiable). */
@property (readonly) BOOL isIdentifiable;

/** A fully qualified identifier is like the identifier but better. 
  * It includes the full path to the file, meaning that if multiple databases of the same identifier are presently open from different paths on disk, they will also be unique. */
@property (strong, readonly, nonnull) NSString *fullyQualifiedIdentifier;

/** An optional delegate for the database package controller. */
@property (readonly, weak, nullable) id<MPDatabasePackageControllerDelegate> delegate;

/** The notification center to which notifications about objects of this database package post notifications to.
  * The default implementation returns [NSNotificationCenter defaultCenter], but the subclass
  * (for instance a database package controller used to back a NSDocument) can provide its own. */
@property (strong, readonly, nonnull) NSNotificationCenter *notificationCenter;

/** The snapshot controller. */
@property (strong, readonly, nonnull) MPSnapshotsController *snapshotsController;

/** Create and persist a snapshot of this package.
  * @param name A name for the snapshot. Must be non-nil, but not necessarily unique.
  * @param An optional error pointer. */
- (nullable MPSnapshot *)newSnapshotWithName:(nonnull NSString *)name error:(NSError *__nullable *__nullable)err;

/** Restore the state of the database package using a named snapshot.
 * @param name The name of the snapshot to restore the state for the package from.
 * @param err An error pointer. */
- (BOOL)restoreFromSnapshotWithName:(nonnull NSString *)name error:(NSError *__nullable *__nullable)err;

/** Returns a database package controller with the specified identifier, if one happens to be currently open. */
+ (nullable instancetype)databasePackageControllerWithFullyQualifiedIdentifier:(nonnull NSString *)identifier;

/** Root sections represent are 'virtual' model objects intended to present views to objects in the database package. */
@property (strong, readonly, nonnull) NSArray<MPRootSection *> *rootSections;

/** The active draft is the draft user is presently viewing and editing. */
@property (strong, readwrite, nullable) MPDraft *activeDraft;

/** Returns a managed object given the identifier. */
- (nullable __kindof MPManagedObject *)objectWithIdentifier:(nonnull NSString *)identifier;

/** WAL Checkpoints the specified databases. */
- (BOOL)checkpointDatabases:(nonnull NSArray<MPDatabase *>*)databases error:(NSError *__nullable *__nullable)err;

/** Root section class names ordered in the priority order needed. */
+ (nonnull NSArray<NSString *>*)orderedRootSectionClassNames;

- (void)startListenerWithCompletionHandler:(nonnull void(^)(NSError * _Nullable err))completionHandler;
- (void)stopListener;

/** Called at the end of initializer on the main thread to initialize the persistent state of the database (e.g. fixed data needed by your system). */
- (nullable id)ensureInitialStateInitialized;

/** Called at the end of initializer on the main thread to initialize example data (i.e. optional data supplied in addition to the initial state that is fixed). */
- (nullable id)ensurePlaceholderInitialized;

#pragma mark - 

/** Saves the database as well, a manifest, as well as a JSON dictionary representation. */
- (BOOL)saveToURL:(nonnull NSURL *)URL error:(NSError *__nullable *__nullable)error;

/** Relative URL to a file that contains a preview of the database package.
  * URL is relative to the URL of the database package controller. */
@property (readonly, nonnull) NSURL *relativePreviewURL;

/** Relative URL to a file that contains a thumbnail of the database package.
 * URL is relative to the URL of the database package controller. */
@property (readonly, nonnull) NSURL *relativeThumbnailURL;

/** Absolute URL pointing at a preview of the database package. */
@property (readonly, nonnull) NSURL *absolutePreviewURL;

/** AbsoluteURL pointing at a thumbnail of the database package. */
@property (readonly, nonnull) NSURL *absoluteThumbnailURL;

/** URL from which to find a manifest for the database package. */
@property (readonly, nonnull) NSURL *manifestDictionaryURL;

/** URL from which to find a dictionary representation for the database package. */
@property (readonly, nonnull) NSURL *dictionaryRepresentationURL;

/** The manifest dictionary includes metadata intended for consuming the database package without opening the database proper. */
@property (readonly, nonnull) NSDictionary *manifestDictionary;

/** JSON encodable dictionary representation of all objects in the database package. */
@property (readonly, nonnull) NSDictionary *dictionaryRepresentation;

@end

#pragma mark -

typedef NSURL *__nullable(^MPDatabasePackageControllerRootURLHandler)();
typedef void (^MPDatabasePackageControllerUpdateChangeCountHandler)(NSDocumentChangeType changeType);

@interface MPDatabasePackageControllerBlockBasedDelegate : NSObject <MPDatabasePackageControllerDelegate>

/** Package controller parameter is nullable because of a chicken-egg between this delegate and the package controller.
  * It should be set to a non-nil value before the delegate is used. */
- (nonnull instancetype)initWithPackageController:(nullable MPDatabasePackageController *)pkgc
                                   rootURLHandler:(nonnull MPDatabasePackageControllerRootURLHandler)handler
                         updateChangeCountHandler:(nonnull MPDatabasePackageControllerUpdateChangeCountHandler)changeType;

@property (readwrite, weak, nullable) __kindof MPDatabasePackageController *packageController;
@property (readonly, nonnull) MPDatabasePackageControllerRootURLHandler rootURLHandler;
@property (readonly, nonnull) MPDatabasePackageControllerUpdateChangeCountHandler updateChangeCountHandler;

@end
