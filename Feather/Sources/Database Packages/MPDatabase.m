//
//  MPDatabase.m
//  Feather
//
//  Created by Matias Piipari on 16/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPDatabase.h"

#import "NSDictionary+MPManagedObjectExtensions.h"

#import "MPDatabasePackageController.h"
#import "MPDatabasePackageController+Protected.h"
#import "MPManagedObjectsController+Protected.h"

#import <Feather/MPManagedObject+Protected.h>

#import "NSArray+MPExtensions.h"
#import "MPException.h"

@import FeatherExtensions;
@import RegexKitLite;
@import CouchbaseLite;
@import CouchbaseLite.Logging;
@import ObjectiveC;

NSString * const MPDatabaseErrorDomain = @"MPDatabaseErrorDomain";
NSString * const MPDatabaseReplicationFilterNameAcceptedObjects = @"accepted"; //same name used in serverside CouchDB.

@interface MPDatabase ()
{
}

@property (readwrite, strong) MPMetadata *cachedMetadata;
@property (readwrite, strong) MPLocalMetadata *cachedLocalMetadata;


/** Currently ongoing one-off pull replications. Used when opening a database from a remote. */
@property (readonly, strong) NSMutableSet *currentPulls;

/** Currently ongoing one-off push replications. */
@property (readonly, strong) NSMutableSet *currentPushes;


@end

@implementation MPDatabase

+ (void)load {
    srand48(arc4random());
}

- (instancetype)initWithServer:(CBLManager *)server
             packageController:(MPDatabasePackageController *)packageController
                          name:(NSString *)name
                 ensureCreated:(BOOL)ensureCreated
                         error:(NSError **)err
{
    return [self initWithServer:server packageController:packageController name:name
                  ensureCreated:ensureCreated
                 pushFilterName:nil
                 pullFilterName:nil
                          error:err];
}

- (instancetype)initWithServer:(CBLManager *)server
             packageController:(MPDatabasePackageController *)packageController
                          name:(NSString *)name
                 ensureCreated:(BOOL)ensureCreated
                pushFilterName:(NSString *)pushFilterName
                pullFilterName:(NSString *)pullFilterName
                         error:(NSError **)err
{
    if (self = [super init])
    {
        //EnableLogTo(CBLReplication, YES);
        //EnableLogTo(Sync, YES);
        
        _server = server;
        
        _name = name;
        
        assert(packageController);
        _packageController = packageController;
        
        __block NSError *e = nil;
        mp_dispatch_sync(_server.dispatchQueue, packageController.serverQueueToken, ^{
            _database = [_server databaseNamed:[MPDatabase sanitizedDatabaseIDWithString:name] error:&e];
        });
        
        if (!_database) {
            NSParameterAssert(err);
            if (err)
                *err = e;
            
            self = nil;
            return self;
        }
        
        objc_setAssociatedObject(_database, "dbp", self, OBJC_ASSOCIATION_ASSIGN);
        
        _currentPulls = [NSMutableSet setWithCapacity:5];
        _currentPushes = [NSMutableSet setWithCapacity:5];
                        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(databaseDidChange:)
                                                     name:kCBLDatabaseChangeNotification
                                                   object:_database];
         
        _pushFilterName = pushFilterName;
        _pullFilterName = pullFilterName;
        
         __weak MPDatabase *slf = self;
         
         [self.database setValidationNamed:@"validate-managed-object"
         asBlock:^(CBLRevision *newRevision, id<CBLValidationContext> context) {
             MPDatabase *strongSelf = slf;
             NSCAssert(![newRevision.properties[@"objectType"] isEqualToString:@"MPElement"],
                      @"Unexpected objectType: %@", newRevision.properties[@"objectType"]);
             [strongSelf validateRevision:newRevision validationContext:context];
         }];
         
         // used for backbone-couchdb bridging
        
        mp_dispatch_sync(_server.dispatchQueue, [self.packageController serverQueueToken], ^{
            [[self.database viewNamed:@"by-object-type"]
             setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit)
             {
                 if (doc[@"objectType"])
                     emit(doc[@"objectType"], doc);
             } version:@"1.0"];
        });
    }
    
    return self;
}
         
 - (BOOL)validateRevision:(CBLRevision *)newRevision validationContext:(id<CBLValidationContext>)context
 {
#ifdef DEBUG
     if ([[NSUserDefaults standardUserDefaults] boolForKey:@"MPFailAllSaves"]) {
         [context rejectWithMessage:@"All saves set to fail. Please toggle off MPFaillAllSaves to successfully save"];
         return NO;
     }
     else if ([[NSUserDefaults standardUserDefaults] objectForKey:@"MPFailSavesWithProbability"]) {
         CGFloat p = [[NSUserDefaults standardUserDefaults] floatForKey:@"MPFailSavesWithProbability"];
         
         double val = (CGFloat)drand48();
         
         if (p > val) {
             [context rejectWithMessage:@"Failing saving because MPFailSavesWithProbability is set to a nonzero value"];
             return NO;
         }
     }
#endif
     
     if (newRevision.isDeletion)
         return YES;
     
     BOOL managedObjectTypeIncluded = newRevision.properties.managedObjectType != nil;
     
     NSString *documentID = newRevision.document.documentID ?: newRevision.properties[@"_id"];
     BOOL idHasValidPrefix = NO;
     
     if (managedObjectTypeIncluded)
         idHasValidPrefix = [documentID hasPrefix:newRevision.properties.managedObjectType];
     
     if (managedObjectTypeIncluded)
     {
         if (!idHasValidPrefix)
         {
             NSString *msg = [NSString stringWithFormat:@"Attempting to save a managed object '%@' without object type as a prefix in _id -- this will fail: %@", documentID, [newRevision properties]];
             MPLog(@"%@", msg);
             [context rejectWithMessage:msg];
             
             return NO;
         }
         
         Class cls = NSClassFromString(newRevision.properties.managedObjectType);
         if (!cls)
         {
             NSString *msg = [NSString stringWithFormat:
                              @"Attempting to save a managed object '%@' with an unexpected object type '%@' -- this will fail.",
                              documentID, newRevision.properties.managedObjectType];
             MPLog(@"%@", msg);
             [context rejectWithMessage:msg];
             
             return NO;
         }
         else
         {
             if (![cls validateRevision:newRevision])
             {
                 NSString *msg = [NSString stringWithFormat:@"Attempting to save a managed object '%@' which does not validate as %@ -- this will fail.",
                                  documentID, NSStringFromClass(cls)];
                 MPLog(@"%@", msg);
                 [context rejectWithMessage:msg];
                 
                 return NO;
             }
         }
         
         return idHasValidPrefix;
     }
     
     if (!idHasValidPrefix)
         idHasValidPrefix = [documentID hasPrefix:@"MPMetadata"];
     
     if (!idHasValidPrefix)
         idHasValidPrefix = [documentID hasPrefix:@"MPLocalMetadata"];
     
     if (!idHasValidPrefix)
         NSLog(@"Attempting to save an object '%@' without the expected _id prefix -- this will fail: %@",
               documentID, newRevision.properties);
     
     return idHasValidPrefix;
 }

- (BOOL)validateFilters
{
    if (_pushFilterName && ![self filterWithQualifiedName:self.pushFilterName])
    {
        // indicates a serious bug, should crash also release builds.
        @throw [NSException exceptionWithName:@"MPFilterValidationException"
                                       reason:[NSString stringWithFormat:
                                               @"Filter with name '%@' is missing.", _pushFilterName]
                                     userInfo:nil];
        return NO;
    }
    
    return YES;
}

- (void)defineFilterNamed:(NSString *)name block:(CBLFilterBlock)block
{
    NSAssert(![self.database filterNamed:name], @"Expecting a filter with name '%@' not to exist in database with name %@", name, self.name);
    [self.database setFilterNamed:name asBlock:block];
}

- (void)dealloc
{
    objc_removeAssociatedObjects(_database);
    
    for (id pull in _currentPulls)
    {
        if ([pull observationInfo])
            [pull removeObserver:self forKeyPath:@"completed" context:nil];
    }
    
    for (id push in _currentPushes)
    {
        if ([push observationInfo])
            [push removeObserver:self forKeyPath:@"completed" context:nil];
    }
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self];
}

+ (NSString *)sanitizedDatabaseIDWithString:(NSString *)string
{
    return [string stringByReplacingOccurrencesOfRegex:@"\\.*" withString:@""];
}

- (NSURL *)remoteDatabaseURL
{
    assert(_packageController);
    return [self.packageController remoteDatabaseURLForLocalDatabase:self];
}

- (NSURL *)remoteServiceURL
{
    assert(_packageController);
    return [self.packageController remoteServiceURLForLocalDatabase:self];
}

- (NSURLCredential *)remoteDatabaseCredentials
{
    return [self.packageController remoteDatabaseCredentialsForLocalDatabase:self];
}

+ (BOOL)validateRemoteDatabaseURL:(NSURL *)url error:(NSError **)err
{
    /*
    if (!url)
    {
        if (err)
            *err = [NSError errorWithDomain:MPDatabaseErrorDomain
                                       code:MPDatabaseErrorCodeRemoteUnconfigured
                                   userInfo:@{NSLocalizedDescriptionKey : @"Syncing has not been configured."} ];
        return NO;
    }
    
    RESTOperation *dbInfo = [[CBLDatabase databaseWithURL:url] GET];
    
    __block NSError *validationError = nil;
    [dbInfo onCompletion:^{
        NSLog(@"Validation response: %@", dbInfo.responseBody.asString);
        
        if (dbInfo.response.statusCode != 200)
        {
            validationError = [NSError errorWithDomain:MPDatabaseErrorDomain code:MPDatabaseErrorCodeRemoteInvalid
                                              userInfo:@{NSLocalizedDescriptionKey : @"Unexpected response from the syncing service."} ];
        }
    }];
    [dbInfo wait];
    */
    return YES;
}

- (NSString *)qualifiedPushFilterName
{
    if (!self.pushFilterName) return nil;
    return [NSString stringWithFormat:@"%@/%@", self.name, self.pushFilterName];

}
- (NSString *)qualifiedPullFilterName { return self.pullFilterName; }

- (CBLFilterBlock)filterWithQualifiedName:(NSString *)name
{
    assert(name);
    return [self.database filterNamed:[NSString stringWithFormat:@"%@/%@", self.name, name]];
}


- (BOOL)remoteDatabaseExists
{
    /*
    NSString *dbName = [self.remoteDatabaseURL lastPathComponent];
    CBLDatabase *remoteDB = [CBLDatabase databaseNamed:dbName onServerWithURL:[self.packageController remoteURL]];
    RESTOperation *remoteDBInfo = [remoteDB GET];
    [remoteDBInfo onCompletion:^{}];
    [remoteDBInfo wait];
    
    return remoteDBInfo.response.statusCode == 200;
     */
    return NO;
}

- (BOOL)pushToRemote:(CBLReplication **)replication error:(NSError **)err
{
    NSError *e = nil;
    if (![MPDatabase validateRemoteDatabaseURL:self.remoteDatabaseURL error:&e])
    {
        return NO;
    }
    
    return [self _pushToRemote:replication error:err];
}

- (BOOL)_pushToRemote:(CBLReplication **)replication error:(NSError **)err
{
    return [self pushToDatabaseAtURL:self.remoteDatabaseURL replication:replication error:err];
}

- (BOOL)pushToDatabaseAtURL:(NSURL *)url
                replication:(CBLReplication **)replication
                      error:(NSError *__autoreleasing *)err
{
    [self validateFilters];
    
    CBLReplication *oneOffPush = [self.database createPushReplication:url];
    oneOffPush.continuous = NO;
    
    if ([self.packageController applyFilterWhenPushingToDatabaseAtURL:url fromDatabase:self])
        oneOffPush.filter = self.qualifiedPushFilterName;
    
    [_currentPushes addObject:oneOffPush];
    
    [oneOffPush start];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(replicationDidChange:)
                                                 name:kCBLReplicationChangeNotification
                                               object:oneOffPush];
    
    if (replication)
        *replication = oneOffPush;
    
    return YES;
}
         
- (void)replicationDidChange:(NSNotification *)notification
{
    CBLReplication *replication = notification.object;
    MPLog(@"Pushing to remote %@ finished.", self.remoteDatabaseURL);
    
    if (replication.status == kCBLReplicationStopped)
    {
        [_currentPushes removeObject:replication];
        [_currentPulls removeObject:replication];
        
        if (replication.lastError)
        {
            [[self.packageController notificationCenter] postErrorNotification:replication.lastError];
        }
        
        // remove the observation once status reaches kCBLReplicationStopped
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kCBLReplicationChangeNotification object:replication];
    }
}

- (BOOL)pullFromRemote:(CBLReplication **)replication error:(NSError **)err
{
    if (![MPDatabase validateRemoteDatabaseURL:self.remoteDatabaseURL error:err])
        return NO;
    
    return [self _pullFromRemote:replication error:err];
}

- (BOOL)_pullFromRemote:(CBLReplication **)replication error:(NSError **)err
{
    return [self pullFromDatabaseAtURL:self.remoteDatabaseURL
                           replication:replication
                                 error:err];
}

- (BOOL)pullFromDatabaseAtURL:(NSURL *)url
                  replication:(CBLReplication *__autoreleasing *)replication
                        error:(NSError **)err
{
    [self validateFilters];
    
    CBLReplication *oneOffPull = [self.database createPullReplication:url];
    oneOffPull.continuous = NO;
    
    if ([self.packageController applyFilterWhenPullingFromDatabaseAtURL:url toDatabase:self]) {
        oneOffPull.filter = self.qualifiedPullFilterName;
    }
    
    [oneOffPull start];
    [_currentPulls addObject:oneOffPull];
    
    if (replication) {
        *replication = oneOffPull;
    }
    
    return YES;
}

- (BOOL)pullFromDatabaseAtPath:(NSString *)path
                   replication:(CBLReplication *__autoreleasing *)replication
                         error:(NSError *__autoreleasing *)err
{
    CBLManager *server = [[CBLManager alloc] initWithDirectory:[path stringByDeletingLastPathComponent] options:nil error:err];
    objc_setAssociatedObject(server, "dbp", self.packageController, OBJC_ASSOCIATION_ASSIGN);
    server.etagPrefix = [[NSUUID UUID] UUIDString]; // TODO: persist the etag inside the package for added performance (this gives predictable behaviour: every app start effectively clears the cache).
    
    if (!server)
    {
        return NO;
    }
    
    CBLDatabase *db = [server databaseNamed:[[path lastPathComponent] stringByDeletingPathExtension]
                                      error:err];
    if (!db)
    {
        return NO;
    }
    
    CBLReplication *repl = [db createPushReplication:self.database.internalURL];
    repl.continuous = NO;
    repl.createTarget = NO;
    
    repl.filter = [self qualifiedPullFilterName];
    
    [repl start];
    
    if (replication)
        *replication = repl;
    
    return YES;
}

- (void)databaseDidChange:(NSNotification *)notification
{
    if (!_packageController)
        return;
    
    NSAssert(_packageController, @"Expecting a non-nil package controller for database '%@'",
                      self.name);
    
    CBLDatabase *db = (CBLDatabase *)notification.object;
    //NSLog(@"%@ database changed", self.name);
    
    NSAssert(db == self.database, @"Expecting %@ (%@) == %@ (%@)", db, db.name, self.database, self.database.name);
    
    BOOL isExternalChange = [notification.userInfo[@"external"] boolValue];
    for (CBLDatabaseChange *change in notification.userInfo[@"changes"])
    {
        __block CBLDocument *doc = nil;
        mp_dispatch_sync(self.database.manager.dispatchQueue,
                         [self.packageController serverQueueToken],
        ^{
            doc = [self.database existingDocumentWithID:change.documentID];
        });
        
        MPManagedObjectChangeSource src = isExternalChange
                                            ? MPManagedObjectChangeSourceExternal
                                            : MPManagedObjectChangeSourceAPI;
        
        if (!doc) {
            Class cls = [MPManagedObject managedObjectClassFromDocumentID:change.documentID];
            MPManagedObjectsController *moc = [self.packageController controllerForManagedObjectClass:cls];
            
            // moc may be nil and the below code therefore not executed when change is for MPMetadata / MPLocalMetadata object.
            CBLDocument *doc = [moc documentWithIdentifier:change.documentID allDocsMode:kCBLIncludeDeleted];
            if ([doc.currentRevisionID isEqualToString:change.revisionID]) {
                MPManagedObject *mo = [moc objectWithIdentifier:doc.documentID];
                if (mo) {
                    [moc didDeleteObject:mo];
                }
            }
        }
        else {
            [_packageController didChangeDocument:doc source:src];
        }
    }
}

- (BOOL)ensureRemoteDatabaseCreated:(NSError **)err
{
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

// https://github.com/couchbaselabs/TouchDB-iOS/wiki/Guide%3A-Replication
- (BOOL)syncWithRemote:(NSError **)error
{
    [self validateFilters];
    
    if (![self ensureRemoteDatabaseCreated:error])
        return NO;
    
    CBLReplication *pull = [self.database createPullReplication:self.remoteDatabaseURL];
    pull.continuous = YES;
    [_currentPulls addObject:pull];
    
    CBLReplication *push = [self.database createPushReplication:self.remoteDatabaseURL];
    push.continuous = YES;
    [_currentPushes addObject:push];
    
    [self addObserver:self forPersistentReplication:pull];
    [self addObserver:self forPersistentReplication:push];
    
    return YES;
}

- (void)addObserver:(id)object forPersistentReplication:(CBLReplication *)replication
{
    // TODO: check through that these properties are still the ones to observe
    [replication addObserver:self forKeyPath:@"completed" options:0 context:NULL];
    [replication addObserver:self forKeyPath:@"status" options:0 context:NULL];
    [replication addObserver:self forKeyPath:@"total" options:0 context:NULL];
    [replication addObserver:self forKeyPath:@"error" options:0 context:NULL];
    [replication addObserver:self forKeyPath:@"mode" options:0 context:NULL];
}

- (void) observeValueForKeyPath:(NSString *)keyPath
         ofObject:(id)object
         change:(NSDictionary *)change
         context:(void *)context
{
    if ([_currentPulls containsObject:object]
        || [_currentPushes containsObject:object])
    {
        CBLReplication *replication = object;
        
        NSUInteger completedPull = 0;
        NSUInteger totalPull = 0;
        NSUInteger completedPush = 0;
        NSUInteger totalPush = 0;
        NSUInteger completed = 0;
        NSUInteger total = 0;
        
        for (CBLReplication *pull in _currentPulls)
            {
                completedPull += pull.completedChangesCount; totalPull += pull.changesCount;
            }
        
        for (CBLReplication *push in _currentPushes)
            {
                completedPush += push.completedChangesCount; totalPush += push.changesCount;
            }
        
        completed = completedPull + completedPush;
        total = totalPull + totalPush;
        
        if (total > 0 && completed < total)
        {
            NSLog(@"Replication status: %lu / %lu of pull, %lu / %lu of push in mode %d (%.2f total)",
                      completedPull, totalPull,
                      completedPush, totalPush, replication.status,
                      completed / (float)total);
        }
        else if (total > 0)
        {
            NSLog(@"Replication completed: 1.0");
            // TODO: Detect completion
        }
    }
    
    if ([object respondsToSelector:@selector(error)]) {
        if ([object error])
        {
            NSLog(@"%@ error: %@", object, [object error]);
        }
    }
}

- (MPMetadata *)metadata
{
    if (!_cachedMetadata)
    {
        NSString *metadataDocID = [NSString stringWithFormat:@"MPMetadata:%@", [self name]];
        _cachedMetadata = [MPMetadata modelForDocument:[self.database documentWithID:metadataDocID] ];
        assert(_cachedMetadata);
        
        NSError *err = nil;
        if (![_cachedMetadata save:&err])
        {
            NSLog(@"ERROR! Failed to save database metadata: %@", _cachedMetadata);
            [[self.packageController notificationCenter] postErrorNotification:err];
        }
    }
    
    return _cachedMetadata;
}

- (NSString *)identifier {
    assert(self.metadata);
    return self.metadata.document.documentID;
}

- (MPMetadata *)localMetadata
{
    if (!_cachedLocalMetadata)
    {
        NSString *localMetadataDocID = [NSString stringWithFormat:@"_local/MPMetadata:%@", [self name]];
        _cachedLocalMetadata = [MPLocalMetadata modelForDocument:[self.database documentWithID:localMetadataDocID]];
        assert(_cachedLocalMetadata);
        
        NSError *err = nil;
        if (![_cachedLocalMetadata save:&err])
        {
            NSLog(@"ERROR! Failed to save database metadata: %@", _cachedLocalMetadata);
            [[self.packageController notificationCenter] postErrorNotification:err];
        }
    }
    
    return _cachedLocalMetadata;
}

#pragma mark - Scriptability

- (NSScriptObjectSpecifier *)objectSpecifier {
    NSParameterAssert(self.packageController);
    NSScriptObjectSpecifier *parentSpec = [self.packageController objectSpecifier];

    assert(parentSpec.keyClassDescription);
    return [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:parentSpec.keyClassDescription
                                                       containerSpecifier:parentSpec key:@"orderedDatabases" uniqueID:self.identifier];
}

- (id)valueInMetadataWithUniqueID:(NSString *)uid {
    assert([self.metadata.document.documentID isEqualToString:uid]);
    return self.metadata;
}

@end


@implementation MYDynamicObject (Feather)

- (void)setValuesForPropertiesWithDictionary:(NSDictionary *)keyedValues
{
    for (id key in [keyedValues allKeys])
    {
        [self setValue:keyedValues[key] ofProperty:key];
    }
}

@end

typedef void (^CBLDatabaseDoAsyncHandler)();

@implementation CBLDatabase (Feather)

+ (void)load
{
    /*
    [CBLDatabase replaceInstanceMethodWithSelector:@selector(doAsync:) implementationBlockProvider:^id(IMP originalImplementation) {
        return ^(CBLDatabase *receiver, CBLDatabaseDoAsyncHandler block) {
            if (receiver.packageController) {
                mp_dispatch_async(receiver.manager.dispatchQueue,
                                 [receiver.packageController serverQueueToken],
                                  ^{
                                      block();
                                 });
            }
            else {
                originalImplementation(receiver, @selector(doAsync:), block);
            }
        };
    }];
     */
}

- (id)managedObjectDatabaseBackpointer
{
    return objc_getAssociatedObject(self, "dbp");
}

- (id)packageController
{
    MPDatabase *dbp = [self managedObjectDatabaseBackpointer];
    if (!dbp)
        return nil; // some databases don't have the backpointer set, for instance ones created through replication.
    
    assert(dbp.packageController);
    assert([dbp.packageController isKindOfClass:MPDatabasePackageController.class]);
    return dbp.packageController;
}

- (NSArray *)getManagedObjectsWithIDs:(NSArray *)ids
{
    assert([self packageController]);
    CBLQueryEnumerator *rows = [self getDocumentsWithIDs:ids];
    NSMutableArray *objs = [NSMutableArray arrayWithCapacity:rows.count];
    for (CBLQueryRow *row in rows) {
        CBLDocument *doc = row.document;
        
        MPManagedObject *mo = nil;
        if (!doc) {
            mo = [[self packageController] objectWithIdentifier:row.key]; // can be in a different database, or the shared package.
        }
        else {
            mo = [[MPManagedObject managedObjectClassFromDocumentID:doc.documentID] modelForDocument:doc];
        }
        
        if (mo) {
            [objs addObject:mo];
        } else {
            MPLog(@"WARNING: Failed to recover object by ID %@", row.documentID);
        }
    }
    
    return objs.copy;
}

- (CBLQueryEnumerator *)getDocumentsWithIDs:(NSArray *)docIDs
{
    CBLQuery *query = [self createAllDocumentsQuery];
    query.keys = docIDs;
    query.prefetch = YES;
    
    NSError *err = nil;
    CBLQueryEnumerator *rows = [query run:&err];
    
    if (!rows)
    {
        NSLog(@"ERROR! Failed to get documents with IDs '%@':\n%@", docIDs, err);
    }
    
    return rows;
}

- (NSArray *)plainObjectsFromQueryEnumeratorKeys:(CBLQueryEnumerator *)rows
{
    NSMutableArray* entries = [NSMutableArray arrayWithCapacity:rows.count];
    for (CBLQueryRow *row in rows)
    {
        [entries addObject:row.key];
    }
    return entries;
}

@end

@implementation CBLManager (MPDatabase)

- (id)managedObjectDatabaseBackpointer
{
    return objc_getAssociatedObject(self, "dbp");
}

- (id)packageController
{
    MPDatabase *dbp = [self managedObjectDatabaseBackpointer];
    assert(dbp);
    assert([dbp packageController]);
    assert([[dbp packageController] isKindOfClass:[MPDatabasePackageController class]]);
    return [dbp packageController];
}

@end

@implementation CBLQuery (MPDatabase)

- (CBLQueryEnumerator *)run
{
    __block CBLQueryEnumerator *qenum = nil;
    mp_dispatch_sync(self.database.manager.dispatchQueue, [[self.database packageController] serverQueueToken], ^{
        NSError *err = nil;
        if (!(qenum = [self run:&err]))
        {
            [[self.database.packageController notificationCenter] postErrorNotification:err];
        }
        
    });
    return qenum;
}

@end

@implementation MPMetadata

- (BOOL)save
{
    __block NSError *err = nil;
    __block BOOL success = NO;
    
    mp_dispatch_sync(self.database.manager.dispatchQueue, [self.database.packageController serverQueueToken], ^{
        success = [self save:&err];
    });
    
    if (!success)
        [[NSNotificationCenter defaultCenter] postErrorNotification:err];
    
    return success;
}

- (id)getValueOfProperty:(NSString *)property
{
    __block id value = nil;
    mp_dispatch_sync(self.database.manager.dispatchQueue, [[self.database packageController] serverQueueToken], ^{
        value = [super getValueOfProperty:property];
    });
    return value;
}

- (NSString *)JSONStringRepresentation:(NSError *__autoreleasing *)error {
    __block NSData *data = nil;
    
    mp_dispatch_sync(self.database.manager.dispatchQueue, [[self.database packageController] serverQueueToken], ^{
        data = [NSJSONSerialization dataWithJSONObject:self.propertiesToSave
                                               options:NSJSONWritingPrettyPrinted
                                                 error:error];
    });
    
    if (!data)
        return nil;
    
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

#pragma mark - Scripting support

- (NSString *)identifier {
    assert(self.document);
    return self.document.documentID;
}

- (NSDictionary *)scriptingProperties {
    NSMutableDictionary *dict = [[self propertiesToSave] mutableCopy];
    [dict removeObjectForKey:@"_id"];
    [dict removeObjectForKey:@"_rev"];
    return [dict copy];
}

- (void)setScriptingProperties:(NSDictionary *)scriptingProperties {
    for (id k in scriptingProperties) {
        [self setValue:scriptingProperties[k] ofProperty:k];
    }
}

- (NSScriptObjectSpecifier *)objectSpecifier
{
    assert(self.document);
    assert(self.document.documentID);
    
    id pkgc = [self.database packageController];
    NSString *primaryDBName = [[pkgc class] primaryDatabaseName];
    assert(primaryDBName);
    
    MPDatabase *db = [pkgc databaseWithName:primaryDBName];
    assert(db);
    
    NSScriptObjectSpecifier *containerRef = [db objectSpecifier];
    
    return [[NSPropertySpecifier alloc] initWithContainerClassDescription:[NSScriptClassDescription classDescriptionForClass:MPDatabase.class]
                                                       containerSpecifier:containerRef key:@"metadata"];
}

- (id)handleKeyedValueCommand:(NSScriptCommand *)command {
    id key = command.evaluatedArguments[@"WithKey"];
    return [self getValueOfProperty:key];
}

- (void)handleModifyKeyedValuesCommand:(NSScriptCommand *)command {
    NSDictionary *dict = command.evaluatedArguments[@"WithProperties"];
    NSParameterAssert([dict isKindOfClass:NSDictionary.class]);
    for (id k in dict) {
        [self setValue:dict[k] ofProperty:k];
    }
}

@end

@implementation MPLocalMetadata
@end
