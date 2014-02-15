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


NSString * const MPDatabaseErrorDomain = @"MPDatabaseErrorDomain";

NSString * const MPDatabaseReplicationFilterNameAcceptedObjects = @"accepted"; //same name used in serverside CouchDB.

@interface MPDatabase ()
{
}

@property (readonly, strong) dispatch_queue_t queryQueue;
@property (readwrite, strong) MPMetadata *cachedMetadata;
@property (readwrite, strong) MPLocalMetadata *cachedLocalMetadata;

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
        _server = server;
        
        _name = name;
        
        _packageController = packageController;
        
        NSError *err = nil;
        _database = [_server databaseNamed:[MPDatabase sanitizedDatabaseIDWithString:name] error:&err];
        
        objc_setAssociatedObject(_database, "dbp", self, OBJC_ASSOCIATION_ASSIGN);
        
        _currentPullOperations = [NSMutableArray arrayWithCapacity:5];
        _currentPushOperations = [NSMutableArray arrayWithCapacity:5];
        _currentOneOffPulls = [NSMutableArray arrayWithCapacity:5];
        _currentOneOffPushes = [NSMutableArray arrayWithCapacity:5];
        
        _queryQueue =
            dispatch_queue_create(
                [[NSString stringWithFormat:@"com.piipari.db[%@][%@]", server.internalURL.path, name] UTF8String],
                                  DISPATCH_QUEUE_SERIAL);
        
        #warning Ensure that tracksChanges has simply been removed and doesn't have to be replaced.
        //_database.tracksChanges = YES;
        
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
    if (_pushFilterName && ![self filterWithName:self.pushFilterName])
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

// Filters defined via MPDatabase to not expose primaryDesignDocument in public interface.
// This is so there is no temptation to add custom views / filters there.
- (void)defineFilterNamed:(NSString *)name block:(CBLFilterBlock)block
{
    assert(![self.database filterNamed:name]);
    
    [self.database defineFilter:name asBlock:block];
    
    // GCD fun! The -defineFilterNamed: call above actually causes work to be scheduled on the TouchDB thread.
    // this helps make it synchronized.
    dispatch_semaphore_t synchronizer = dispatch_semaphore_create(0);
    
    [self.database.manager backgroundTellDatabaseNamed:self.name to:^(CBLDatabase *db) {
        assert(db == self.database);
        dispatch_semaphore_signal(synchronizer);
    }];
    
    dispatch_semaphore_wait(synchronizer, DISPATCH_TIME_FOREVER);
}

- (void)dealloc
{
    objc_removeAssociatedObjects(_database);
    
    for (id pull in _currentPullOperations)
    {
        if ([pull observationInfo])
            [pull removeObserver:self forKeyPath:@"completed" context:nil];
    }
    
    for (id push in _currentPushOperations)
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
    
    return YES;
}

- (NSString *)qualifiedPushFilterName
{
    if (!self.pushFilterName) return nil;
    return [NSString stringWithFormat:@"%@/%@", self.name, self.pushFilterName];

}
- (NSString *)qualifiedPullFilterName { return self.pullFilterName; }

- (CBLFilterBlock)filterWithName:(NSString *)name
{
    assert(name);
    __block CBLFilterBlock blk = nil;

    dispatch_semaphore_t synchronizer = dispatch_semaphore_create(0);
    [(CouchTouchDBServer *)self.database.server tellTDDatabaseNamed:[self name] to:^(TD_Database *tdb) {
        blk = [tdb filterNamed:[NSString stringWithFormat:@"%@/%@", [self name], name]];
        dispatch_semaphore_signal(synchronizer);
    }];
    
    dispatch_semaphore_wait(synchronizer, DISPATCH_TIME_FOREVER);
    return blk;
}

- (BOOL)remoteDatabaseExists
{
    NSString *dbName = [self.remoteDatabaseURL lastPathComponent];
    CBLDatabase *remoteDB = [CouchDatabase databaseNamed:dbName onServerWithURL:[self.packageController remoteURL]];
    RESTOperation *remoteDBInfo = [remoteDB GET];
    [remoteDBInfo onCompletion:^{}];
    [remoteDBInfo wait];
    
    return remoteDBInfo.response.statusCode == 200;
}

- (BOOL)pushToRemote:(NSError **)err
{
    NSError *e = nil;
    if (![MPDatabase validateRemoteDatabaseURL:self.remoteDatabaseURL error:&e])
    {
        return NO;
    }
    
    return [self _pushToRemote:err];
}

- (BOOL)_pushToRemote:(NSError **)err
{
    [self pushToDatabaseAtURL:self.remoteDatabaseURL error:err];
}

- (BOOL)pushToDatabaseAtURL:(NSURL *)url error:(NSError *__autoreleasing *)err
{
    [self validateFilters];
    
    CBLReplication *oneOffPush = [self.database createPushReplication:url];
    oneOffPush.continuous = NO;
    
    if ([self.packageController applyFilterWhenPushingToDatabaseAtURL:url fromDatabase:self])
        oneOffPush.filter = self.qualifiedPushFilterName;
    
    [_currentOneOffPushes addObject:oneOffPush];
    
    [oneOffPush start];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(replicationDidChange:)
                                                 name:kCBLReplicationChangeNotification
                                               object:nil];
    
    [_currentPushOperations addObject:oneOffPush];
}
         
- (void)replicationDidChange:(NSNotification *)notification
{
    CBLReplication *replication = notification.object;
    MPLog(@"Pushing to remote %@ finished.", self.remoteDatabaseURL);
    
    if (!replication.status == kCBLReplicationStopped)
    {
        [_currentPushOperations removeObject:replication];
        [_currentPullOperations removeObject:replication];
        
        if (replication.lastError)
        {
            [[self.packageController notificationCenter] postErrorNotification:replication.lastError];
        }
    }
}

- (BOOL)pullFromRemote:(NSError **)err
{
    if (![MPDatabase validateRemoteDatabaseURL:self.remoteDatabaseURL error:err])
        return NO;
    
    [self _pullFromRemote:err];
}

- (BOOL)_pullFromRemote:(NSError **)err
{
    return [self pullFromDatabaseAtURL:self.remoteDatabaseURL error:err];
}

- (BOOL)pullFromDatabaseAtURL:(NSURL *)url error:(NSError **)err
{
    [self validateFilters];
    
    CBLReplication *oneOffPull = [self.database createPullReplication:url];
    oneOffPull.continuous = NO;
    
    if ([self.packageController applyFilterWhenPullingFromDatabaseAtURL:url toDatabase:self])
        oneOffPull.filter = self.qualifiedPullFilterName;
    
    [_currentOneOffPulls addObject:oneOffPull];
    
    [oneOffPull start];
    [_currentPullOperations addObject:oneOffPull];
}

- (void)pullFromDatabaseAtPath:(NSString *)path
{
    NSError *err = nil;
    CBLManager *server = [[CBLManager alloc] initWithDirectory:path options:nil error:&err];
    if (!server)
    {
        assert(err);
        dispatch_async(dispatch_get_main_queue(), ^{
            pullHandler(err);
        });
    }
    
    CBLDatabase *db = [server databaseNamed:path.lastPathComponent.stringByDeletingPathExtension error:&err];
    
    if (!db)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            pullHandler(err);
        });
    }
    
    CBLReplication *repl = [db createPushReplication:self.database.internalURL];
    repl.continuous = NO;
    repl.createTarget = NO;
    
    [repl start];
}

- (void)databaseDidChange:(NSNotification *)notification
{
    CBLDatabase *db = (CBLDatabase *)notification.object;
    if (db != self.database) return;
    
    NSLog(@"Database changed: %@", notification.object);
    
    BOOL isExternalChange = notification.userInfo[@"external"];
    
    assert(_packageController);
    [_packageController didChangeDocument:doc
                                   source:
     isExternalChange ? MPManagedObjectChangeSourceExternal : MPManagedObjectChangeSourceAPI];
}

- (BOOL)ensureRemoteDatabaseCreated:(NSError **)err
{
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

// https://github.com/couchbaselabs/TouchDB-iOS/wiki/Guide%3A-Replication
- (void)syncWithRemoteWithCompletionHandler:(void (^)(NSError *err))syncHandler
{
    [self validateFilters];
    
    NSError *error = nil;
    if (![self ensureRemoteDatabaseCreated:&error])
    {
        assert(error);
        syncHandler(error);
        return;
    }
    
    CBLReplication *pull = [self.database createPullReplication:self.remoteDatabaseURL];
    pull.continuous = YES;
    [_currentPullOperations addObject:pull];
    
    CBLReplication *push = [self.database createPushReplication:self.remoteDatabaseURL];
    push.continuous = YES;
    [_currentPushOperations addObject:push];
    
    [self addObserver:self forPersistentReplication:pull];
    [self addObserver:self forPersistentReplication:push];
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
    if ([_currentPullOperations containsObject:object] || [_currentPushOperations containsObject:object])
    {
        NSUInteger completedPull = 0;
        NSUInteger totalPull = 0;
        NSUInteger completedPush = 0;
        NSUInteger totalPush = 0;
        NSUInteger completed = 0;
        NSUInteger total = 0;
        
        for (CBLReplication *pull in _currentPullOperations)
            { completedPull += pull.completedChangesCount; totalPull += pull.changesCount; }
        
        for (CBLReplication *push in _currentPushOperations)
            { completedPush += push.completedChangesCount; totalPush += push.changesCount; }
        
        completed = completedPull + completedPush;
        total = totalPull + totalPush;
        
        if (total > 0 && completed < total)
        {
            NSLog(@"Replication status: %lu / %lu of pull, %lu / %lu of push in mode %d (%.2f total)",
                      completedPull, totalPull,
                      completedPush, totalPush, [(CouchPersistentReplication *)object mode],
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


@implementation CouchDynamicObject (Feather)

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

- (MPManagedObject *)getManagedObjectWithID:(NSString *)identifier
{
    return [[self getManagedObjectsWithIDs:@[identifier]] firstObject];
}

- (CBLDocument *)getDocumentWithID:(NSString *)docID
{
    CBLQueryEnumerator *qe = [self getDocumentsWithIDs:@[docID]];
    assert(qe.count < 2);
    return qe.nextRow.document;
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

- (NSArray *)plainObjectsFromQueryEnumeratorKeys:(CouchQueryEnumerator *)rows
{
    NSMutableArray* entries = [NSMutableArray arrayWithCapacity:rows.count];
    for (CouchQueryRow *row in rows)
    {
        [entries addObject:[row key]];
    }
    return entries;
}

@end

@implementation MPMetadata
@end