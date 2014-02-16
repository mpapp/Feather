//
//  MPDatabase.h
//  Feather
//
//  Created by Matias Piipari on 16/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CouchbaseLite/CouchbaseLite.h>

extern NSString * const MPDatabaseErrorDomain;

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

/** The filesystem path to the database .touchdb file. */
@property (readonly, copy) NSString *path;

/** Name of the database, which is unique per MPDatabasePackageController, and used to derive the database's filesystem path and the remote URL. Immutable, readonly property set during instantiation. */
@property (readonly, copy) NSString *name;

/** The CouchServer instance which owns this database (the server can have multiple databases and is itself managed by MPDatabasePackageController). */
@property (readonly, strong) CBLManager *server;

/** The CBLDatabase instance wrapped by the MPDatabase instance.  */
@property (readonly, strong) CBLDatabase *database;

/** A metadata document stored in the database. Each document has one metadata document (found by its pre-defined identifier). It is intended to store a small number of key--value pairs which do not change regularly. */
@property (readonly, strong) MPMetadata *metadata;

/** A local (non-replicated) metadata document stored in the database. */
@property (readonly, strong) MPMetadata *localMetadata;

/** A weak back pointer to the database controller. Typed id to avoid casting -- MPDatabasePackageController is an abstract class and a concrete subclass  is needed in the application. */
@property (readonly, weak) id packageController; // subclass of MPDatabasePackageController

/**
 * @param server CouchServer from which the database is to be found. Should be one of the CouchServers owned by the database controller (2nd parameter).
 * @param packageController The database controller which manages this database.
 * @param name A name which is unique for the database package in which this database is contained.
 * @param err Error pointer.
 *
 * A database is created for the CouchServer.
*/
- (instancetype)initWithServer:(CBLManager *)server
             packageController:(MPDatabasePackageController *)packageController
                          name:(NSString *)name
                 ensureCreated:(BOOL)ensureCreated
                         error:(NSError **)err;

/** 
 * @param server CouchServer from which the database is to be found. Should be one of the CouchServers owned by the database controller (2nd parameter).
 * @param packageController The database controller which manages this database.
 * @param name A name which is unique for the database package in which this database is contained.
 * @param pushFilterName The name of the push filter function. Optional parameter (can be nil), but only if pushFilterBlock is nil => no push filter. If non-nil pushFilterName given, there must be a call -defineFilterNamed:block: given for the MPDatabase with the same pushFilterName before replicating it.
 * @param pullFilterName is the name of the pull filter function. Optional parameter (can be nil).
 * @param err Error pointer.
*/
- (instancetype)initWithServer:(CBLManager *)server
             packageController:(MPDatabasePackageController *)packageController
                          name:(NSString *)name
                 ensureCreated:(BOOL)ensureCreated
                pushFilterName:(NSString *)pushFilterName
                pullFilterName:(NSString *)pullFilterName
                         error:(NSError **)err;

/** Utility method for creating a string from a NSString which is safe to be used as a CouchDB database name (excludes certain forbidden characters).
 * @param string An input string, potentially containing characters not allowed in CouchDB database names. */
+ (NSString *)sanitizedDatabaseIDWithString:(NSString *)string;

/** Start a continuous push replication with a remote database. */
- (BOOL)pushToRemote:(CBLReplication **)replication
               error:(NSError **)err;

/** Start a continuous pull replication from a remote database. */
- (BOOL)pullFromRemote:(CBLReplication **)replication
                 error:(NSError **)err;

- (BOOL)pullFromDatabaseAtURL:(NSURL *)url
                  replication:(CBLReplication **)replication
                        error:(NSError **)err;

- (BOOL)pushToDatabaseAtURL:(NSURL *)url
                replication:(CBLReplication **)replication
                      error:(NSError **)err;

- (BOOL)pullFromDatabaseAtPath:(NSString *)path
                   replication:(CBLReplication **)replication
                         error:(NSError **)err;

/** Start a continuous, persistent pull and push replication with a remote database. 
  * @param syncHandler A completion handler run when the request which begins the replication is completed. */
- (BOOL)syncWithRemote:(NSError **)error;

/** Name of the filter function used to filter pulls to this database from a remote. */
@property (readonly, copy) NSString *pullFilterName;

/** Name of the push filter function (a CouchbaseLite CBLFilterBlock) used to filter pushes from the local database to a remote. */
@property (readonly, copy) NSString *pushFilterName;

/** The full name of the pull filter name, including the design document name. */
@property (readonly, copy) NSString *qualifiedPullFilterName;

/** The full name of the push filter name, including the design document name. */
@property (readonly, copy) NSString *qualifiedPushFilterName;

/** Define a new filter function to the database's internal design document (used only for ). Should be called only once per name. */
- (void)defineFilterNamed:(NSString *)name block:(CBLFilterBlock)block;

/** Filter block with a given name, stored in the database's private design document. */
- (CBLFilterBlock)filterWithQualifiedName:(NSString *)name;

/** The default replication URL for this database, used by -syncWithRemoteWithCompletionHandler: , -pushToRemoteWithCompletionHandler: and -pullFromremoteWithCompletionHandler: . Derived from database controller's remote URL and the database name. */
@property (readonly, strong) NSURL *remoteDatabaseURL;

/** The service resoure URL for this database (RESTful resource which allows creation / deletion). */
@property (readonly, strong) NSURL *remoteServiceURL;

/** The remote database exists. */
@property (readonly) BOOL remoteDatabaseExists;

/** Authentication credentials for the remote database. */
@property (readonly, strong) NSURLCredential *remoteDatabaseCredentials;

@end

#pragma mark -

/** A utility category on MYDynamicObject to support MPManagedObject */
@interface MYDynamicObject (MPDatabase)

/** Set values for keys using a dictionary. Allows bulk changes of CouchDynamicObject properties.
  * @param keyedValues A dictionary with property names as keys and and values representing the values to set the properties to. */
- (void)setValuesForPropertiesWithDictionary:(NSDictionary *)keyedValues;

@end

/** A MPDatabase utility category for CBLDatabase. */
@interface CBLDatabase (MPDatabase)

/** A back pointer from a CBLDatabase to its MPDatabasePackageController. This is stored as an ObjC runtime associative reference. The method should only be called on a CBLDatabase owned by a MPDatabasePackageController, as the non-nilness of the database controller pointer is asserted. */
@property (readonly, weak) id packageController;

/** Get managed object model objects for documents specified by the array of IDs from the database. */
- (NSArray *)getManagedObjectsWithIDs:(NSArray *)ids;
/** Get managed object model objects for documents specified by the ID from the database. */
- (MPManagedObject *)getManagedObjectWithID:(NSString *)identifier;

/** Get document by ID. Returns nil if no object were found. */
- (CBLDocument *)getDocumentWithID:(NSString *)identifier;

/** Get plain JSON encodable objects for query enumerator. */
- (NSArray *)plainObjectsFromQueryEnumeratorKeys:(CBLQueryEnumerator *)rows;


@end

/**
 * A metadata document: a maximum of one metadata document is stored per database (think of it like NSUserDefaults stored in a CouchDB-like database).
 * MPMetadata inherits directly from CouchModel and not from MPManagedObject to avoid a requirement to have a managed objects controller for it, which would would a) be unnecessary and b) would introduce a MOC <=> MPDatabase retain cycle.
 */
@interface MPMetadata : CBLModel
@end

/**
 * A local metadata document: a maximum of one local metadata document is stored per database. The word 'local' means that it is not replicated with remote hosts.
 */
@interface MPLocalMetadata : MPMetadata
@end