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

#import <Feather/Feather.h>
#import <Feather/MPManagedObject+Protected.h>
#import "RegexKitLite.h"

#import "NSArray+MPExtensions.h"
#import "MPException.h"

#import <Feather/NSNotificationCenter+MPExtensions.h>
#import <Feather/NSNotificationCenter+ErrorNotification.h>
#import <Feather/NSBundle+MPExtensions.h>

#import <CouchbaseLite/CouchbaseLite.h>

#import <objc/runtime.h>
#import <objc/message.h>

#import <CouchbaseLite/Logging.h>

NSString * const MPDatabaseErrorDomain = @"MPDatabaseErrorDomain";
NSString * const MPDatabaseReplicationFilterNameAcceptedObjects = @"accepted"; //same name used in serverside CouchDB.

@interface MPDatabase ()
{
}

@property (readonly, strong) dispatch_queue_t queryQueue;
@property (readwrite, strong) MPMetadata *cachedMetadata;
@property (readwrite, strong) MPLocalMetadata *cachedLocalMetadata;


/** Currently ongoing one-off pull replications. Used when opening a database from a remote. */
@property (readonly, strong) NSMutableSet *currentPulls;

/** Currently ongoing one-off push replications. */
@property (readonly, strong) NSMutableSet *currentPushes;


@end

@implementation MPDatabase

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
        
        _packageController = packageController;
        
        NSError *err = nil;
        _database = [_server databaseNamed:[MPDatabase sanitizedDatabaseIDWithString:name] error:&err];
        
        objc_setAssociatedObject(_database, "dbp", self, OBJC_ASSOCIATION_ASSIGN);
        
        _currentPulls = [NSMutableSet setWithCapacity:5];
        _currentPushes = [NSMutableSet setWithCapacity:5];
        
        _queryQueue =
            dispatch_queue_create(
                [[NSString stringWithFormat:@"com.piipari.db[%@][%@]", server.internalURL.path, name] UTF8String],
                                  DISPATCH_QUEUE_SERIAL);
                
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
             [strongSelf validateRevision:newRevision validationContext:context];
         }];
         
         // used for backbone-couchdb bridging
         [[self.database viewNamed:@"by-object-type"]
          setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit)
        {
            if (doc[@"objectType"])
                emit(doc[@"objectType"], doc);
        } version:@"1.0"];
    }
    
    return self;
}
         
 - (BOOL)validateRevision:(CBLRevision *)newRevision validationContext:(id<CBLValidationContext>)context
 {
     if (newRevision.isDeletion) return YES;
     
     BOOL managedObjectTypeIncluded = newRevision.properties.managedObjectType != nil;
     
     BOOL idHasValidPrefix = NO;
     if (managedObjectTypeIncluded)
         idHasValidPrefix = [newRevision.document.documentID hasPrefix:newRevision.properties.managedObjectType];
     
     if (managedObjectTypeIncluded)
     {
         if (!idHasValidPrefix)
         {
             NSLog(@"Attempting to save a managed object '%@' without object type as a prefix in _id -- this will fail: %@", newRevision.document.documentID, [newRevision properties]);
             return NO;
         }
         
         Class cls = NSClassFromString(newRevision.properties.managedObjectType);
         if (!cls)
         {
             NSLog(@"Attempting to save a managed object '%@' with an unexpected object type '%@' -- this will fail.",
                   newRevision.document.documentID, newRevision.properties.managedObjectType);
             return NO;
         }
         else
         {
             if (![cls validateRevision:newRevision])
             {
                 NSLog(@"Attempting to save a managed object '%@' which does not validate as %@ -- this will fail.",
                       newRevision.document.documentID, NSStringFromClass(cls));
                 return NO;
             }
         }
         
         return idHasValidPrefix;
     }
     
     if (!idHasValidPrefix)
         idHasValidPrefix = [newRevision.document.documentID hasPrefix:@"MPMetadata"];
     
     if (!idHasValidPrefix)
         idHasValidPrefix = [newRevision.document.documentID hasPrefix:@"MPLocalMetadata"];
     
     if (!idHasValidPrefix)
         NSLog(@"Attempting to save an object '%@' without the expected _id prefix -- this will fail: %@",
               newRevision.document.documentID, newRevision.properties);
     
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
    assert(![self.database filterNamed:name]);
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
    
    if ([self.packageController applyFilterWhenPullingFromDatabaseAtURL:url toDatabase:self])
        oneOffPull.filter = self.qualifiedPullFilterName;
    
    [oneOffPull start];
    [_currentPulls addObject:oneOffPull];
    
    if (replication)
        *replication = oneOffPull;
    
    return YES;
}

- (BOOL)pullFromDatabaseAtPath:(NSString *)path
                   replication:(CBLReplication *__autoreleasing *)replication
                         error:(NSError *__autoreleasing *)err
{
    CBLManager *server = [[CBLManager alloc] initWithDirectory:[path stringByDeletingLastPathComponent] options:nil error:err];
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
    
    [repl start];
    
    if (replication)
        *replication = repl;
    
    return YES;
}

- (void)databaseDidChange:(NSNotification *)notification
{
    assert(_packageController);
    
    CBLDatabase *db = (CBLDatabase *)notification.object;
    NSLog(@"Database changed: %@", db);
    
    if (db != self.database)
        return;
    
    BOOL isExternalChange = notification.userInfo[@"external"];
    for (CBLDatabaseChange *change in notification.userInfo[@"changes"])
    {
        CBLDocument *doc = [self.database existingDocumentWithID:change.documentID];
        [_packageController didChangeDocument:doc
                                       source:isExternalChange
                                                ? MPManagedObjectChangeSourceExternal
                                                : MPManagedObjectChangeSourceAPI];
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
    #warning check through that these properties are still the ones to observe
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

- (MPMetadata *)localMetadata
{
    if (!_cachedLocalMetadata)
    {
        NSString *localMetadataDocID = [NSString stringWithFormat:@"_local/MPMetadata:%@", [self name]];
        _cachedLocalMetadata = [MPLocalMetadata modelForDocument:[self.database documentWithID:localMetadataDocID]];
        assert(_cachedLocalMetadata);
        
        NSError *err = nil;
        if ([_cachedLocalMetadata save:&err])
        {
            NSLog(@"ERROR! Failed to save database metadata: %@", _cachedLocalMetadata);
            [[self.packageController notificationCenter] postErrorNotification:err];
        }
    }
    
    return _cachedLocalMetadata;
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

@implementation CBLDatabase (Feather)

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

- (NSArray *)getManagedObjectsWithIDs:(NSArray *)ids
{
    assert([self packageController]);
    CBLQueryEnumerator *rows = [self getDocumentsWithIDs:ids];
    NSMutableArray *objs = [NSMutableArray arrayWithCapacity:rows.count];
    for (CBLQueryRow *row in rows)
    {
        CBLDocument *doc = row.document;
        MPManagedObject *mo = [[MPManagedObject managedObjectClassFromDocumentID:doc.documentID] modelForDocument:doc];
        assert(mo);
        [objs addObject:mo];
    }
    return objs;
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

@implementation CBLQuery (MPDatabase)

- (CBLQueryEnumerator *)run
{
    NSError *err = nil;
    CBLQueryEnumerator *qenum = nil;
    if (!(qenum = [self run:&err]))
    {
        [[self.database.packageController notificationCenter] postErrorNotification:err];
    }
    return qenum;
}

@end

@implementation MPMetadata

- (BOOL)save
{
    NSError *err = nil;
    BOOL success = [self save:&err];
    
    if (!success)
        [[NSNotificationCenter defaultCenter] postErrorNotification:err];
    
    return success;
}

@end

@implementation MPLocalMetadata
@end
