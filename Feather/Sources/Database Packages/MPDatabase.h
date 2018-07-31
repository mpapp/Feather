//
//  MPDatabase.h
//  Feather
//
//  Created by Matias Piipari on 16/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Foundation;
@import CouchbaseLite;
@import FeatherExtensions.MPJSONRepresentable;

extern NSString * _Nonnull const MPDatabaseErrorDomain;

typedef enum MPDatabaseErrorCode
{
    MPDatabaseErrorCodeUnknown = 0,
    MPDatabaseErrorCodeRemoteUnconfigured = 1,
    MPDatabaseErrorCodeRemoteInvalid = 2,
    MPDatabaseErrorCodePushAlreadyInProgress = 3,
    MPDatabaseErrorCodePullAlreadyInProgress = 4
} MPDatabaseErrorCode;

@class MPDatabasePackageController;
@class MPMetadata;
@class MPManagedObject;

/** MPDatabase wraps a CBLDatabase and allows it to be pull and push replicated with a remote database.
 * The database is managed by a MPDatabasePackageController. */
@interface MPDatabase : NSObject

/** The filesystem path to the database .cblite file. */
//@property (readonly, copy) NSString *path;

/** Name of the database, which is unique per MPDatabasePackageController, and used to derive the database's filesystem path and the remote URL. Immutable, readonly property set during instantiation. */
@property (nonnull, readonly, copy) NSString *name;

/** The CBLManager instance which owns this database (the server can have multiple databases and is itself managed by MPDatabasePackageController). */
@property (nullable, readonly, weak) CBLManager *server;

/** The CBLDatabase instance wrapped by the MPDatabase instance.  */
@property (nonnull, readonly, strong) CBLDatabase *database;

/** A metadata document stored in the database. Each document has one metadata document (found by its pre-defined identifier). It is intended to store a small number of key--value pairs which do not change regularly. */
@property (nonnull, readonly, strong) MPMetadata *metadata;

@property (nonnull, readonly, copy) NSString *identifier;

/** A local (non-replicated) metadata document stored in the database. */
@property (nonnull, readonly, strong) MPMetadata *localMetadata;

/** A weak back pointer to the database controller. Typed id to avoid casting -- MPDatabasePackageController is an abstract class and a concrete subclass  is needed in the application. */
@property (nullable, readonly, weak) __kindof MPDatabasePackageController *packageController; // subclass of MPDatabasePackageController

/**
 * @param server CouchServer from which the database is to be found. Should be one of the CouchServers owned by the database controller (2nd parameter).
 * @param packageController The database controller which manages this database.
 * @param name A name which is unique for the database package in which this database is contained.
 * @param err Error pointer.
 *
 * A database is created for the CouchServer.
*/
- (instancetype _Nonnull )initWithServer:(CBLManager *_Nonnull)server
                       packageController:(MPDatabasePackageController *_Nonnull)packageController
                                    name:(NSString *_Nonnull)name
                           ensureCreated:(BOOL)ensureCreated
                                   error:(NSError *_Nonnull*_Nonnull)err;

/**
 * @param server CouchServer from which the database is to be found. Should be one of the CouchServers owned by the database controller (2nd parameter).
 * @param packageController The database controller which manages this database.
 * @param name A name which is unique for the database package in which this database is contained.
 * @param pushFilterName The name of the push filter function. Optional parameter (can be nil), but only if pushFilterBlock is nil => no push filter. If non-nil pushFilterName given, there must be a call -defineFilterNamed:block: given for the MPDatabase with the same pushFilterName before replicating it.
 * @param pullFilterName is the name of the pull filter function. Optional parameter (can be nil).
 * @param err Error pointer.
*/
- (instancetype _Nonnull )initWithServer:(CBLManager *_Nonnull)server
                       packageController:(MPDatabasePackageController *_Nonnull)packageController
                                    name:(NSString *_Nonnull)name
                           ensureCreated:(BOOL)ensureCreated
                          pushFilterName:(NSString *_Nullable)pushFilterName
                          pullFilterName:(NSString *_Nullable)pullFilterName
                                   error:(NSError *_Nonnull*_Nonnull)err;

/** Utility method for creating a string from a NSString which is safe to be used as a CouchDB database name (excludes certain forbidden characters).
 * @param string An input string, potentially containing characters not allowed in CouchDB database nam_Nonnulles. */
+ (NSString *_Nonnull)sanitizedDatabaseIDWithString:(NSString *_Nonnull)string;

/** Start a continuous push replication with a remote database. */
- (BOOL)pushToRemote:(CBLReplication *_Nullable*_Nullable)replication
               error:(NSError *_Nonnull*_Nonnull)err;

/** Start a continuous pull replication from a remote database. */
- (BOOL)pullFromRemote:(CBLReplication *_Nullable*_Nullable)replication
                 error:(NSError *_Nonnull*_Nonnull)err;

- (BOOL)pullFromDatabaseAtURL:(NSURL *_Nonnull)url
                  replication:(CBLReplication *_Nonnull*_Nonnull)replication
                        error:(NSError *_Nonnull*_Nonnull)err;

- (BOOL)pushToDatabaseAtURL:(NSURL *_Nonnull)url
                replication:(CBLReplication *_Nonnull*_Nonnull)replication
                      error:(NSError *_Nonnull*_Nonnull)err;

- (BOOL)pullFromDatabaseAtPath:(NSString *_Nonnull)path
                   replication:(CBLReplication *_Nonnull*_Nonnull)replication
                         error:(NSError *_Nonnull*_Nonnull)err;

/** Start a continuous, persistent pull and push replication with a remote database. */
- (BOOL)syncWithRemote:(NSError *_Nonnull*_Nonnull)error;

/** Name of the filter function used to filter pulls to this database from a remote. */
@property (readonly, copy) NSString * _Nonnull pullFilterName;

/** Name of the push filter function (a CouchbaseLite CBLFilterBlock) used to filter pushes from the local database to a remote. */
@property (readonly, copy) NSString * _Nonnull pushFilterName;

/** The full name of the pull filter name, including the design document name. */
@property (readonly, copy) NSString * _Nonnull qualifiedPullFilterName;

/** The full name of the push filter name, including the design document name. */
@property (readonly, copy) NSString * _Nonnull qualifiedPushFilterName;

/** Define a new filter function to the database's internal design document (used only for ). Should be called only once per name. */
- (void)defineFilterNamed:(NSString *_Nonnull)name block:(CBLFilterBlock _Nonnull )block;

/** Filter block with a given name, stored in the database's private design document. */
- (CBLFilterBlock _Nonnull )filterWithQualifiedName:(NSString *_Nonnull)name;

/** The default replication URL for this database, used by -syncWithRemoteWithCompletionHandler: , -pushToRemoteWithCompletionHandler: and -pullFromremoteWithCompletionHandler: . Derived from database controller's remote URL and the database name. */
@property (nullable, readonly, strong) NSURL *remoteDatabaseURL;

/** The service resoure URL for this database (RESTful resource which allows creation / deletion). */
@property (nullable, readonly, strong) NSURL *remoteServiceURL;

/** The remote database exists. */
@property (readonly) BOOL remoteDatabaseExists;

/** Authentication credentials for the remote database. */
@property (nullable, readonly, strong) NSURLCredential *remoteDatabaseCredentials;

@end

#pragma mark -

/** A utility category on MYDynamicObject to support MPManagedObject */
@interface MYDynamicObject (MPDatabase)

/** Set values for keys using a dictionary. Allows bulk changes of CouchDynamicObject properties.
  * @param keyedValues A dictionary with property names as keys and and values representing the values to set the properties to. */
- (void)setValuesForPropertiesWithDictionary:(NSDictionary *_Nonnull)keyedValues;

@end

/** A MPDatabase utility category for CBLDatabase. */
@interface CBLDatabase (MPDatabase)

/** A back pointer from a CBLDatabase to its MPDatabasePackageController. This is stored as an ObjC runtime associative reference. The method should only be called on a CBLDatabase owned by a MPDatabasePackageController, as the non-nilness of the database controller pointer is asserted. */
@property (nullable, readonly, weak) id packageController;

@property (nonatomic, readonly) BOOL isOpen;

/** Get managed object model objects for documents specified by the array of IDs from the database. */
- (NSArray <MPManagedObject *> *_Nullable)getManagedObjectsWithIDs:(NSArray *_Nonnull)ids;

/** A query enumerator to get documents with the specified IDs. */
- (CBLQueryEnumerator *_Nullable)getDocumentsWithIDs:(NSArray *_Nonnull)docIDs;

/** Get plain JSON encodable objects for query enumerator. */
- (NSArray <CBLQueryRow *> *_Nonnull)plainObjectsFromQueryEnumeratorKeys:(CBLQueryEnumerator *_Nonnull)rows;

@end

@interface CBLManager (MPDatabase)

/** A back pointer from a CBLDatabase to its MPDatabasePackageController. This is stored as an ObjC runtime associative reference. The method should only be called on a CBLDatabase owned by a MPDatabasePackageController, as the non-nilness of the database controller pointer is asserted. */
@property (nullable, readonly, weak) id packageController;

@end

@interface CBLQuery (MPDatabase)

/** Runs a query, and returns a query enumerator if successful, and nil if unsuccessful.
 *  If error occurs, posts the error in an error notification to the database's package controller's notification center. */
- (nullable CBLQueryEnumerator *)run;

@end

/**
 * A metadata document: a maximum of one metadata document is stored per database (think of it like NSUserDefaults stored in a CouchDB-like database).
 * MPMetadata inherits directly from CouchModel and not from MPManagedObject to avoid a requirement to have a managed objects controller for it, which would would a) be unnecessary and b) would introduce a MOC <=> MPDatabase retain cycle.
 */
@interface MPMetadata : CBLModel <MPJSONRepresentable>

/** Saves and posts an error notification on errors to the object's package controller's notification center. */
- (BOOL)save;

@end

/**
 * A local metadata document: a maximum of one local metadata document is stored per database. The word 'local' means that it is not replicated with remote hosts.
 */
@interface MPLocalMetadata : MPMetadata
@end
