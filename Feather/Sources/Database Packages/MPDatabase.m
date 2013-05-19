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
#import <Feather/MPManagedObject+Protected.h>
#import "RegexKitLite.h"

#import "NSArray+MPExtensions.h"
#import <Feather/NSBundle+MPExtensions.h>
#import "MPException.h"

#import <objc/runtime.h>
#import <objc/message.h>

#import <CouchCocoa/CouchCocoa.h>
#import <CouchCocoa/CouchReplication.h>
#import <TouchDB/TouchDB.h>

NSString * const MPDatabaseErrorDomain = @"MPDatabaseErrorDomain";

NSString * const MPDatabaseReplicationFilterNameAcceptedObjects = @"accepted"; //same name used in serverside CouchDB.

@interface MPDatabase ()
{
    CouchDesignDocument *_primaryDesignDocument;
    CouchChangeTracker *_changeTracker;
    NSTimer *_replicationRestartTimer;
}

@property (readonly, strong) dispatch_queue_t queryQueue;
@property (readwrite, strong) MPMetadata *cachedMetadata;
@property (readwrite, strong) MPLocalMetadata *cachedLocalMetadata;

@end

@implementation MPDatabase

- (instancetype)initWithServer:(CouchServer *)server
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

- (instancetype)initWithServer:(CouchServer *)server
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
        
        _database = [_server databaseNamed:[MPDatabase sanitizedDatabaseIDWithString:name]];
        
        if (ensureCreated)
            if (![_database ensureCreated:err]) return nil;
        
        objc_setAssociatedObject(_database, "dbp", self, OBJC_ASSOCIATION_ASSIGN);
        
        _currentPersistentPulls = [NSMutableArray arrayWithCapacity:5];
        _currentPullOperations = [NSMutableArray arrayWithCapacity:5];
        _currentPushOperations = [NSMutableArray arrayWithCapacity:5];
        _currentPersistentPushes = [NSMutableArray arrayWithCapacity:5];
        _currentOneOffPulls = [NSMutableArray arrayWithCapacity:5];
        _currentOneOffPushes = [NSMutableArray arrayWithCapacity:5];
        
        _queryQueue =
            dispatch_queue_create(
                [[NSString stringWithFormat:@"com.piipari.db[%@][%@]", server.URL.path, name] UTF8String],
                                  DISPATCH_QUEUE_SERIAL);
        
        _database.tracksChanges = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(databaseDidChange:)
                                                     name:kCouchDatabaseChangeNotification
                                                   object:_database];
        
        _pushFilterName = pushFilterName;
        _pullFilterName = pullFilterName;
        
        if ([server isKindOfClass:[CouchTouchDBServer class]])
        {
            [self.primaryDesignDocument setValidationBlock:
             ^BOOL(TD_Revision *newRevision, id<TD_ValidationContext> context)
             {
                 if (newRevision.deleted) return YES;
                 
                 BOOL managedObjectTypeIncluded = newRevision.properties.managedObjectType != nil;
                 
                 BOOL idHasValidPrefix = NO;
                 if (managedObjectTypeIncluded)
                     idHasValidPrefix = [newRevision.docID hasPrefix:newRevision.properties.managedObjectType];
                 
                 if (managedObjectTypeIncluded)
                 {
                     if (!idHasValidPrefix)
                         NSLog(@"Attempting to save a managed object '%@' without object type as a prefix in _id -- this will fail: %@",
                               newRevision.docID, [newRevision properties]);
                     return idHasValidPrefix;
                 }
                 
                 if (managedObjectTypeIncluded)
                 {
                     Class cls = NSClassFromString(newRevision.properties.managedObjectType);
                     if (!cls)
                     {
                         NSLog(@"Attempting to save a managed object '%@' with an unexpected object type '%@' -- this will fail.",
                               newRevision.docID, newRevision.properties.managedObjectType);
                         return NO;
                     }
                     else
                     {
                         if (![cls validateRevision:newRevision])
                         {
                             NSLog(@"Attempting to save a managed object '%@' which does not validate as %@ -- this will fail.",
                                   newRevision.docID, NSStringFromClass(cls));
                             return NO;
                         }
                     }
                 }
                 
                 if (!idHasValidPrefix)
                     idHasValidPrefix = [newRevision.docID hasPrefix:@"MPMetadata"];
                 
                 if (!idHasValidPrefix)
                     idHasValidPrefix = [newRevision.docID hasPrefix:@"MPLocalMetadata"];
                 
                 if (!idHasValidPrefix)
                     NSLog(@"Attempting to save an object '%@' without the expected _id prefix -- this will fail: %@",
                           newRevision.docID, [newRevision properties]);
                     
                 return idHasValidPrefix;
             }];
        }
        
        
    }
    
    return self;
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

- (CouchDesignDocument *)primaryDesignDocument
{
    if (!_primaryDesignDocument)
    {
        assert([self name]);
        assert(self.database);
        _primaryDesignDocument = [self.database designDocumentWithName:[self name]];
        
        // used for backbone-couchdb bridging
        [_primaryDesignDocument defineViewNamed:@"byCollection" mapBlock:^(NSDictionary *doc, TDMapEmitBlock emit) {
            if (doc[@"objectType"])
                emit(doc[@"objectType"], doc);
        } version:@"1.0"];
        
        [_primaryDesignDocument defineFilterNamed:@"by_collection"
                                            block:
         ^BOOL(TD_Revision *revision, NSDictionary *params) {
             
             if (revision.properties[@"objectType"] && params[@"query"]
                 && params[@"query"][@"collection"]
                 && [params[@"query"][@"collection"] isEqualToString:revision.properties[@"objectType"]])
                 return YES;
             
             else if (params[@"query"]
                      && params[@"query"][@"collection"]
                      && revision.deleted)
                 return YES;
             
             else
                 return NO;
         }];
    }
    
    return _primaryDesignDocument;
}

// Filters defined via MPDatabase to not expose primaryDesignDocument in public interface.
// This is so there is no temptation to add custom views / filters there.
- (void)defineFilterNamed:(NSString *)name block:(TD_FilterBlock)block
{
    assert(![self.primaryDesignDocument filters][name]);
    [self.primaryDesignDocument defineFilterNamed:name block:block];
    
    // GCD fun! The -defineFilterNamed: call above actually causes work to be scheduled on the TouchDB thread.
    // this helps make it synchronized.
    dispatch_semaphore_t synchronizer = dispatch_semaphore_create(0);
    [(CouchTouchDBServer *)self.database.server tellTDDatabaseNamed:[self name] to:^(TD_Database *tdb) {
        dispatch_semaphore_signal(synchronizer);
    }];
    
    dispatch_semaphore_wait(synchronizer, DISPATCH_TIME_FOREVER);
}

- (void)dealloc
{
    objc_removeAssociatedObjects(_database);
    
    for (id persistentPull in _currentPersistentPulls)
    {
        if ([persistentPull observationInfo])
            [persistentPull removeObserver:self forKeyPath:@"completed" context:nil];
    }
    
    for (id persistentPush in _currentPersistentPushes)
    {
        if ([persistentPush observationInfo])
            [persistentPush removeObserver:self forKeyPath:@"completed" context:nil];
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
    
    RESTOperation *dbInfo = [[CouchDatabase databaseWithURL:url] GET];
    
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

- (TD_FilterBlock)filterWithName:(NSString *)name
{
    assert(name);
    __block TD_FilterBlock blk = nil;

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
    CouchDatabase *remoteDB = [CouchDatabase databaseNamed:dbName onServerWithURL:[self.packageController remoteURL]];
    RESTOperation *remoteDBInfo = [remoteDB GET];
    [remoteDBInfo onCompletion:^{}];
    [remoteDBInfo wait];
    
    return remoteDBInfo.response.statusCode == 200;
}

- (void)pushToRemoteWithCompletionHandler:(void (^)(NSError *err))pushHandler
{
    NSError *e = nil;
    if (![MPDatabase validateRemoteDatabaseURL:self.remoteDatabaseURL error:&e]) { pushHandler(e); return; }
    
    [self _pushToRemoteWithCompletionHandler:pushHandler];
}

- (void)_pushToRemoteWithCompletionHandler:(void (^)(NSError *err))pushHandler
{
    [self pushToDatabaseAtURL:self.remoteDatabaseURL withCompletionHandler:pushHandler];
}

- (void)pushToDatabaseAtURL:(NSURL *)url
       withCompletionHandler:(void (^)(NSError *err))pushHandler
{
    [self validateFilters];
    
    CouchReplication *oneOffPush = [self.database pushToDatabaseAtURL:url];
    
    if ([self.packageController applyFilterWhenPushingToDatabaseAtURL:url fromDatabase:self])
        oneOffPush.filter = self.qualifiedPushFilterName;
    
    [_currentOneOffPushes addObject:oneOffPush];
    
    RESTOperation *pushOperation = [oneOffPush start];
    [_currentPushOperations addObject:pushOperation];
    
    [pushOperation onCompletion:^{
        MPLog(@"Pushing to remote %@ finished.", self.remoteDatabaseURL);
        [_currentPushOperations removeObject:pushOperation];
        pushHandler(pushOperation.error);
    }];
}

- (void)pushPersistentlyToDatabaseAtURL:(NSURL *)url continuously:(BOOL)continuously
                  withCompletionHandler:(void (^)(NSError *))pushHandler
{
    [self validateFilters];
    
    CouchPersistentReplication *push = [self.database replicationToDatabaseAtURL:url];
    
    if ([self.packageController applyFilterWhenPushingToDatabaseAtURL:url fromDatabase:self])
        push.filter = self.qualifiedPushFilterName;
    
    [_currentPersistentPushes addObject:push];
    push.continuous = continuously;
    
    [self addObserver:self forPersistentReplication:push];
}

- (void)pullFromRemoteWithCompletionHandler:(void (^)(NSError *))pullHandler
{
    NSError *e = nil;
    if (![MPDatabase validateRemoteDatabaseURL:self.remoteDatabaseURL error:&e]) { pullHandler(e); return; }
    
    [self _pullFromRemoteWithCompletionHandler:pullHandler];
}

- (void)_pullFromRemoteWithCompletionHandler:(void (^)(NSError *err))pullHandler
{
    [self pullFromDatabaseAtURL:self.remoteDatabaseURL withCompletionHandler:pullHandler];
}

- (void)pullFromDatabaseAtURL:(NSURL *)url
        withCompletionHandler:(void (^)(NSError *))pullHandler
{
    [self validateFilters];
    
    CouchReplication *oneOffPull = [self.database pullFromDatabaseAtURL:url];
    
    if ([self.packageController applyFilterWhenPullingFromDatabaseAtURL:url toDatabase:self])
        oneOffPull.filter = self.qualifiedPullFilterName;
    
    [_currentOneOffPulls addObject:oneOffPull];
    
    RESTOperation *pullOperation = [oneOffPull start];
    [_currentPullOperations addObject:pullOperation];
    
    [pullOperation onCompletion:^{
        MPLog(@"Pushing to remote %@ finished.", self.remoteDatabaseURL);
        [_currentPullOperations removeObject:pullOperation];
        pullHandler(pullOperation.error);
    }];
}

- (void)pullPersistentlyFromDatabaseAtURL:(NSURL *)url continuously:(BOOL)continuously
        withCompletionHandler:(void (^)(NSError *))pullHandler
{
    [self validateFilters];
    
    CouchPersistentReplication *pull = [self.database replicationFromDatabaseAtURL:url];
    
    if ([self.packageController applyFilterWhenPullingFromDatabaseAtURL:url toDatabase:self])
        pull.filter = self.qualifiedPullFilterName;
    
    [_currentPersistentPulls addObject:pull];
    pull.continuous = continuously;
    
    [self addObserver:self forPersistentReplication:pull];
}

- (void)pullFromDatabaseAtPath:(NSString *)path withCompletionHandler:(void (^)(NSError *))pullHandler
{
    CouchServer *server = [[CouchTouchDBServer alloc] initWithServerPath:[path stringByDeletingLastPathComponent] options:nil];
    CouchDatabase *db = [server databaseNamed:[[path lastPathComponent] stringByDeletingPathExtension]];
    CouchReplication *repl = [db pushToDatabaseAtURL:self.database.URL];
    [repl setContinuous:NO];
    [repl setCreateTarget:NO];
    
    [[repl start] onCompletion:^{
        MPLog(@"Pull complete.");
    }];
}

/*
- (void)restartPersistentReplications:(NSTimer *)timer
{
    [_currentPersistentPull restart];
    //[_currentPersistentPush restart];
}
 */

- (void)databaseDidChange:(NSNotification *)notification
{
    CouchDatabase *db = (CouchDatabase *)notification.object;
    if (db != self.database) return;
    
    NSLog(@"Database changed: %@", notification.object);
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
     
    NSArray *replications = [self.database replicateWithURL:self.remoteDatabaseURL exclusively:NO];
    
    CouchPersistentReplication *currentPersistentPull = replications[0];
    currentPersistentPull.continuous = YES;
    [_currentPersistentPulls addObject:currentPersistentPull];
    
    CouchPersistentReplication *currentPersistentPush = replications[1];
    currentPersistentPush.continuous = YES;
    [_currentPersistentPushes addObject:currentPersistentPush];
    
    [self addObserver:self forPersistentReplication:currentPersistentPull];
    [self addObserver:self forPersistentReplication:currentPersistentPush];
    
    /*
    [NSObject performAsynchronousBlockInMainQueue:^{
        _replicationRestartTimer =
        [NSTimer scheduledTimerWithTimeInterval:30.0f target:self selector:@selector(restartPersistentReplications:) userInfo:nil repeats:YES];
    }];
     */
}

- (void)addObserver:(id)object forPersistentReplication:(CouchPersistentReplication *)replication
{
    [replication addObserver:self forKeyPath:@"completed" options:0 context:NULL];
    [replication addObserver:self forKeyPath:@"status" options:0 context:NULL];
    [replication addObserver:self forKeyPath:@"total" options:0 context:NULL];
    [replication addObserver:self forKeyPath:@"error" options:0 context:NULL];
    [replication addObserver:self forKeyPath:@"mode" options:0 context:NULL];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context
{
    if ([_currentPersistentPulls containsObject:object] || [_currentPersistentPushes containsObject:object])
    {
        NSUInteger completedPull = 0;
        NSUInteger totalPull = 0;
        NSUInteger completedPush = 0;
        NSUInteger totalPush = 0;
        NSUInteger completed = 0;
        NSUInteger total = 0;
        
        for (CouchPersistentReplication *pull in _currentPersistentPulls)
            { completedPull += pull.completed; totalPull += pull.total; }
        
        for (CouchPersistentReplication *push in _currentPersistentPushes)
            { completedPush += push.completed; totalPush += push.total; }
        
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
        
        if (![[_cachedMetadata save] wait:&err] && err)
        {
            NSLog(@"ERROR! Failed to save database metadata: %@", _cachedMetadata);
            [[NSAlert alertWithError:err] runModal];
        }
    }
    
    return _cachedMetadata;
}

- (MPMetadata *)localMetadata
{
    if (!_cachedLocalMetadata)
    {
        NSString *localMetadataDocID = [NSString stringWithFormat:@"_local/MPMetadata:%@", [self name]];
        _cachedLocalMetadata = [MPMetadata modelForDocument:[self.database documentWithID:localMetadataDocID]];
        assert(_cachedLocalMetadata);
        
        NSError *err = nil;
        if (![[_cachedLocalMetadata save] wait:&err] && err)
        {
            NSLog(@"ERROR! Failed to save database metadata: %@", _cachedLocalMetadata);
            [[NSAlert alertWithError:err] runModal];
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

@implementation CouchDatabase (Feather)

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
    CouchQueryEnumerator *rows = [[self getDocumentsWithIDs:ids] rows];
    NSMutableArray *objs = [NSMutableArray arrayWithCapacity:rows.count];
    for (CouchQueryRow *row in rows)
    {
        CouchDocument *doc = row.document;
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

// TODO: Include this in CouchCocoa itself
- (CouchDocument *)getDocumentWithID:(NSString *)docID
{
    CouchQuery *query = [self getAllDocuments];
    query.keys = @[docID];
    query.prefetch = YES;
    
    CouchQueryEnumerator *rows = [query rows];
    assert(rows.count == 0 || rows.count == 1);
    
    return [rows nextRow].document;
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