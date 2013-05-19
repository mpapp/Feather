//
//  MPDatabasePackageController.m
//  Feather
//
//  Created by Matias Piipari on 23/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPDatabase.h"
#import "MPDatabasePackageController+Protected.h"
#import "MPManagedObjectsController+Protected.h"
#import "MPSnapshot+Protected.h"

#import <Feather/NSBundle+MPExtensions.h>

#import "MPContributor.h"
#import "MPContributorsController.h"
#import "MPSnapshotsController.h"
#import "MPException.h"
#import "NSString+MPExtensions.h"
#import "NSObject+MPExtensions.h"

#import "MPSearchIndexController.h"

#import "MPRootSection.h"

#import "JSONKit.h"

#import "RegexKitLite.h"

#import <CouchCocoa/CouchCocoa.h>
#import <CouchCocoa/CouchDesignDocument_Embedded.h>
#import <CouchCocoa/CouchTouchDBDatabase.h>
#import <CouchCocoa/CouchTouchDBServer.h>
#import <TouchDB/TouchDB.h>
#import <TouchDBListener/TDListener.h>

#import <objc/runtime.h>

#import <arpa/inet.h>
#import <net/if.h>
#import <ifaddrs.h>

@interface MPTemporaryDatabasePackageCopyFileManagerDelegate : NSObject
@end

@implementation MPTemporaryDatabasePackageCopyFileManagerDelegate

- (BOOL)fileManager:(NSFileManager *)fileManager shouldCopyItemAtURL:(NSURL *)sourceURL toURL:(NSURL *)destionationURL
{
    NSString *filename = sourceURL.path.lastPathComponent;
    
    if ([filename hasPrefix:@"snapshot"])
    {
        MPLog(@"Will skip snapshots %@ for temporary copies.", filename);
        return NO;
    }
    
    MPLog(@"Will copy %@ to %@", filename, destionationURL.path);
    
    return YES;
}

@end

#pragma mark -

NSString * const MPDatabasePackageControllerErrorDomain = @"MPDatabasePackageControllerErrorDomain";

@interface MPDatabasePackageController ()
{
    NSMutableSet *_managedObjectsControllers;
    MPDatabase *_snapshotsDatabase;
    
    NSMutableArray *_pulls;
    NSMutableArray *_completedPulls;
    MPPullCompletionHandler _pullCompletionHandler;
    
    NSMutableDictionary *_controllerDictionary;
}

@property (strong, readwrite) MPDatabase *snapshotsDatabase;

@property (strong, readwrite) TDListener *databaseListener;
@property (strong, readwrite) NSNetService *databaseListenerService;

@end

@implementation MPDatabasePackageController
@synthesize snapshotsDatabase = _snapshotsDatabase;

- (instancetype)initWithPath:(NSString *)path delegate:(id<MPDatabasePackageControllerDelegate>)delegate
             error:(NSError *__autoreleasing *)err
{
    if (self = [super init])
    {
        assert(path);
        
        _path = path;
        
        _delegate = delegate;
        
        _controllerDictionary = [NSMutableDictionary dictionaryWithCapacity:20];
        
        [self makeNotificationCenter];
        
#ifdef DEBUG
        NSDictionary *headers = @{
            @"Access-Control-Allow-Origin"      : @"*",
            @"Access-Control-Allow-Credentials" : @"true",
            @"Access-Control-Allow-Methods"     : @"POST, GET, PUT, DELETE, OPTIONS",
            @"Access-Control-Allow-Headers"     : @"origin, x-csrftoken, content-type, accept"
        };
#else
        #warning Make editor interactions behave in a CORS-safe way.
        NSDictionary *headers = nil;
#endif
        _server = [[CouchTouchDBServer alloc] initWithServerPath:_path customHTTPHeaders:headers];
        
        CouchTouchDBServer *touchServer = (CouchTouchDBServer *)_server;
        
        if ([touchServer error])
        {
            if (err)
            {
                *err = [touchServer error];
            }
            return nil;
        }
        
        _managedObjectsControllers = [NSMutableSet setWithCapacity:20];
        
        for (NSString *dbName in [[self class] databaseNames])
        {
            NSString *pushFilterName = [self pushFilterNameForDatabaseNamed:dbName];
            MPDatabase *db = [[MPDatabase alloc] initWithServer:_server
                                             packageController:self
                                                           name:dbName
                                                  ensureCreated:YES
                                                 pushFilterName:pushFilterName
                                                 pullFilterName:[self pullFilterNameForDatabaseNamed:dbName]
                                                          error:err];
            
            if (!db) { return nil; }
            [self setValue:db forKey:[NSString stringWithFormat:@"%@Database", db.name]];
            
            if (pushFilterName)
            {
                TD_FilterBlock filterBlock = [self pushFilterBlockWithName:pushFilterName forDatabase:db];
                [db defineFilterNamed:pushFilterName block:filterBlock];
                
                dispatch_semaphore_t synchronizer = dispatch_semaphore_create(0);
                __block TD_FilterBlock blk = nil;
                [(CouchTouchDBServer *)(db.database).server tellTDDatabaseNamed:[db name] to:^(TD_Database *tdb)
                {
                    blk = [tdb filterNamed:[NSString stringWithFormat:@"%@/%@",[db name], pushFilterName]];
                    assert(blk);
                    dispatch_semaphore_signal(synchronizer);
                }];
                
                dispatch_semaphore_wait(synchronizer, DISPATCH_TIME_FOREVER);
                assert(blk);
            }
        }
        
#ifdef DEBUG
        for (NSString *dbName in [[self class] databaseNames])
        {
            id dbObj = [self valueForKey:[NSString stringWithFormat:@"%@Database", dbName]];
            assert([dbObj isKindOfClass:[MPDatabase class]]);
        }
#endif
        
        _contributorsController = [[MPContributorsController alloc] initWithPackageController:self
                                                                                      database:self.primaryDatabase];
        
        assert(_snapshotsDatabase);
        _snapshotsController
            = [[MPSnapshotsController alloc] initWithPackageController:self database:_snapshotsDatabase];
        
        _pulls = [[NSMutableArray alloc] initWithCapacity:[[[self class] databaseNames] count]];
        _completedPulls = [[NSMutableArray alloc] initWithCapacity:[[[self class] databaseNames] count]];
        
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        if ([defs valueForKey:@"MPDefaultsKeySyncPeerlessly"] && [self synchronizesPeerlessly])
        {
            [self startListener];
        }
        
        // populate root section properties
        NSMutableArray *rootSections = [NSMutableArray arrayWithCapacity:[[self class] orderedRootSectionClassNames].count];
        for (NSString *rootSectionClassName in [[self class] orderedRootSectionClassNames])
        {
            Class rootSectionCls = NSClassFromString(rootSectionClassName);
            assert([rootSectionCls isSubclassOfClass:[MPRootSection class]]);
            
            // "MPManuscriptRootSection" => "ManucriptRootSection"
            NSString *classPrefixlessStr = [rootSectionClassName stringByReplacingOccurrencesOfRegex:@"MP" withString:@""];
            // "ManuscriptRootSection"   => "manuscriptRootSection"
            NSString *propertyName = [classPrefixlessStr camelCasedString];
            
            MPRootSection *rootSection = [[rootSectionCls alloc] initWithPackageController:self];
            [self setValue:rootSection forKey:propertyName];
            [rootSections addObject:rootSection];
        }
        
        _rootSections = [rootSections copy];
        
        if ([self indexesObjectFullTextContents])
        {
            _searchIndexController = [[MPSearchIndexController alloc] initWithPackageController:self];
            if (![_searchIndexController ensureCreatedWithError:err])
                return NO;
        }
        
        [[self class] didOpenPackage];
    }
    
    return self;
}

- (BOOL)synchronizesSnapshots { return NO; }

- (BOOL)synchronizesWithRemote { return NO; }

- (BOOL)synchronizesPeerlessly { return YES; }

- (BOOL)controllerExistsForManagedObjectClass:(Class)class
{
    return [self _controllerForManagedObjectClass:class] != nil;
}

- (MPManagedObjectsController *)controllerForManagedObjectClass:(Class)class
{
    MPManagedObjectsController *c = [self _controllerForManagedObjectClass:class];
    if (c) return c;
    
    if (![class conformsToProtocol:@protocol(MPReferencableObject)])
    {
        NSAssert(class != [MPManagedObject class],
                 @"No controller found for non-referencable managed object class %@", class);
    }
    
    _controllerDictionary[NSStringFromClass(class)] = [NSNull null];
    
    return nil;
}

- (MPManagedObjectsController *)_controllerForManagedObjectClass:(Class)class
{
    assert(class);
    assert([class isSubclassOfClass:[MPManagedObject class]] && class != [MPManagedObject class]);
    Class origClass = class;
    
    NSString *origClassName = NSStringFromClass(origClass);
    NSString *controllerPropertyKey = _controllerDictionary[origClassName];
    
    if (controllerPropertyKey && ![controllerPropertyKey isEqual:[NSNull null]])
        return [self valueForKey:controllerPropertyKey];
    else if ([controllerPropertyKey isEqual:[NSNull null]])
        return nil;
    
    // Go back in class hierarchy from class towards MPManagedObject. Should find a suitably named controller.
    MPManagedObjectsController *moc = nil;
    do {
        NSString *className = NSStringFromClass(class);
        assert([className isMatchedByRegex:@"^MP"]);
        
        // MPPublication => MPPublicationsController
        // MPCategory => MPCategoriesController
        NSString *mocProperty = [NSString stringWithFormat:@"%@Controller",
                                 [[[className stringByReplacingOccurrencesOfRegex:
                                    @"^MP" withString:@""] pluralizedString] camelCasedString]];
        
        if ([self respondsToSelector:NSSelectorFromString(mocProperty)])
        {
            MPManagedObjectsController *moc = [self valueForKey:mocProperty];
            assert(moc);
            _controllerDictionary[origClassName] = mocProperty;
            return moc;
        }

    } while (!moc && ((class = [class superclass]) != [MPManagedObject class]));
    
    return moc;
}

+ (Class)_controllerClassForManagedObjectClass:(Class)class
{
    MPManagedObjectsController *moc = nil;
    do {
        NSString *className = NSStringFromClass(class);
        assert([className isMatchedByRegex:@"^MP"]);
        
        // MPPublication => MPPublicationsController
        // MPCategory => MPCategoriesController
        
        NSString *mocClassName = [NSString stringWithFormat:@"%@Controller", [className pluralizedString]];
        
        Class mocClass = NSClassFromString(mocClassName);
        if (mocClass) return mocClass;
        
    } while (!moc && ((class = [class superclass]) != [MPManagedObject class]));
    
    return nil;
}

+ (NSDictionary *)controllerClassForManagedObjectClass:(Class)class
{
    assert([class isSubclassOfClass:[MPManagedObject class]]);
    
    static NSDictionary *controllerDictionary = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:30];
        
        for (Class cls in [[NSObject subclassesForClass:[MPManagedObject class]] arrayByAddingObject:class])
        {
            Class controllerClass = [self _controllerClassForManagedObjectClass:cls];
            
            if (controllerClass)
                dict[NSStringFromClass(cls)] = controllerClass;
        }
        controllerDictionary = [dict copy];
    });
    
    return controllerDictionary[NSStringFromClass(class)];
}

- (MPManagedObjectsController *)controllerForDocument:(CouchDocument *)document
{
    NSString *objType = [document propertyForKey:@"objectType"];
    assert(objType);
    
    Class moClass = NSClassFromString(objType);
    assert(moClass);
    assert([moClass isSubclassOfClass:[MPManagedObject class]] && moClass != [MPManagedObject class]);
    
    MPManagedObjectsController *moc = [self controllerForManagedObjectClass:moClass];
    assert(moc);
    assert(moc.db.database == document.database);
    
    return moc;
}

- (NSNotificationCenter *)notificationCenter
{
    return [NSNotificationCenter defaultCenter]; // subclass can provide its own notification center
}

#pragma mark - Temporary copy creation

- (NSURL *)makeTemporaryCopyWithError:(NSError **)err
{
    assert(self.delegate);
    assert(self.delegate.packageRootURL);
    
    NSURL *packageRootURL = [[self delegate] packageRootURL];
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    NSURL *cachesURL = [fm URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:err];
    
    if (!cachesURL) { return nil; }
    
    NSURL *temporaryDirectoryURL = [cachesURL URLByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
    BOOL isDirectory, exists = [fm fileExistsAtPath:temporaryDirectoryURL.path isDirectory:&isDirectory];
    
    if (exists && !isDirectory)
    {
        if (!isDirectory && err)
            *err = [NSError errorWithDomain:MPDatabasePackageControllerErrorDomain
                                       code:MPDatabasePackageControllerErrorCodeFileNotDirectory
                                   userInfo:@{NSLocalizedDescriptionKey :
                    [NSString stringWithFormat:@"File at URL %@ is not a directory", temporaryDirectoryURL]}];
        return nil;
    }
    else if (!exists)
    {
        BOOL success = [fm createDirectoryAtURL:temporaryDirectoryURL withIntermediateDirectories:NO attributes:nil error:err];
        
        if (!success) {
            MPLog(@"Failed to create temporary directory %@", temporaryDirectoryURL);
            return nil; // TODO: apply proper error propagation here
        }
    }
    
    NSURL *temporaryURL = nil;
    
    do
    {
        NSString *s = [[[NSProcessInfo processInfo] globallyUniqueString] substringToIndex:8];
        temporaryURL = [temporaryDirectoryURL URLByAppendingPathComponent:MPStringF(@"%@_%i.%@", s, (rand() % 10000), packageRootURL.path.pathExtension)];
    }
    while ([fm fileExistsAtPath:temporaryURL.path]);
    
    MPLog(@"Will make temporary document copy into %@", temporaryURL);
    
    MPTemporaryDatabasePackageCopyFileManagerDelegate *fmDelegate = [[MPTemporaryDatabasePackageCopyFileManagerDelegate alloc] init];
    fm.delegate = fmDelegate;
    BOOL success = [fm copyItemAtURL:packageRootURL toURL:temporaryURL error:err];
    
    if (!success)
    {
        return nil;
    }
    
    return temporaryURL;
}

#pragma mark - Databases

-(NSSet *)databases
{
    assert(_managedObjectsControllers);
    assert(_managedObjectsControllers.count);
    
    NSMutableSet *set = [NSMutableSet setWithCapacity:_managedObjectsControllers.count];
    
    for (MPManagedObjectsController *moc in _managedObjectsControllers)
    {
        [set addObject:moc.db];
    }
    
    return [set copy];
}

- (NSSet *)databaseNames
{
    return [self.databases valueForKey:@"name"];
}

+ (NSString *)primaryDatabaseName
{
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; return nil;
}

- (MPDatabase *)databaseWithName:(NSString *)name
{
    assert([self.databaseNames containsObject:name]);
    MPDatabase *db = [self valueForKey:[NSString stringWithFormat:@"%@Database", name]];
    assert(db);
    return db;
}

- (MPDatabase *)primaryDatabase
{
    MPDatabase *db = [self valueForKey:[NSString stringWithFormat:@"%@Database", [[self class] primaryDatabaseName]]];
    assert(db);
    return db;
}

+ (NSSet *)databaseNames
{
    if ([self primaryDatabaseName])
    {
        return [NSSet setWithArray:@[[self primaryDatabaseName], @"snapshots"] ];
    }
    return [NSSet setWithArray:@[ @"snapshots"] ];
}

- (void)setSnapshotsDatabase:(MPDatabase *)snapshotsDatabase { _snapshotsDatabase = snapshotsDatabase; }
- (MPDatabase *)snapshotsDatabase { return _snapshotsDatabase; }

- (void)close
{
    assert(_managedObjectsControllers);
    // multiple MOCs can be connected to the same database.
    NSSet *databases = [_managedObjectsControllers valueForKey:@"db"];
    
    assert(_managedObjectsControllers);
    assert(databases.count > 0);
    
    for (MPDatabase *db in databases)
    {
        [db.server close];
    }
}

#pragma mark - Filter functions

- (NSString *)pushFilterNameForDatabaseNamed:(NSString *)dbName
{
    return nil;
}

- (TD_FilterBlock)createPushFilterBlockWithName:(NSString *)filterName forDatabase:(MPDatabase *)db
{
    assert(!filterName);
    return nil;
}

- (TD_FilterBlock)pushFilterBlockWithName:(NSString *)filterName forDatabase:(MPDatabase *)db
{
    assert(db);
    TD_FilterBlock block = [db filterWithName:filterName];
    if (block) return block;

    return [self createPushFilterBlockWithName:filterName forDatabase:db];
}

- (NSString *)pullFilterNameForDatabaseNamed:(NSString *)dbName
{
    return nil;
}

- (BOOL)applyFilterWhenPullingFromDatabaseAtURL:(NSURL *)url toDatabase:(MPDatabase *)database
{
    return YES;
}

- (BOOL)applyFilterWhenPushingToDatabaseAtURL:(NSURL *)url fromDatabase:(MPDatabase *)database
{
    return YES;
}

#pragma mark - Syncing with a remote server

- (NSURL *)remoteURL
{
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; return nil;
    return nil;
}

- (NSURL *)remoteServiceURL
{
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; return nil;
}

- (NSURL *)remoteDatabaseURLForLocalDatabase:(MPDatabase *)database
{
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; return nil;
}

- (NSURL *)remoteServiceURLForLocalDatabase:(MPDatabase *)database
{
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; return nil;
}

- (NSString *)identifier
{
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; return nil;
}

- (NSURLCredential *)remoteDatabaseCredentialsForLocalDatabase:(MPDatabase *)database
{
    NSSet *databases = [self databases];
    assert([databases containsObject:database]);
    assert([database name]);
    return [[NSURLCredential alloc] initWithUser:@"Administrator"
                                        password:@"f00bar1" persistence:NSURLCredentialPersistenceForSession];
}

+ (NSArray *)databaseURLsForBaseURI:(NSURL *)baseURL
{
    return @[ [NSURL URLWithString:[[baseURL absoluteString] stringByAppendingFormat:@"_snapshots"]] ];
}

- (void)pushToRemoteWithCompletionHandler:(void (^)(NSDictionary *errDict))pushHandler
{
    NSSet *databases = [self databases];
    
    NSMutableDictionary *errDict = [NSMutableDictionary dictionaryWithCapacity:databases.count];
    dispatch_group_t cgrp = dispatch_group_create();
    for (MPDatabase *db in databases)
    {
        dispatch_group_enter(cgrp);
        [db pushToRemoteWithCompletionHandler:^(NSError *err) {
            if (err) errDict[db.name] = err;
            dispatch_group_leave(cgrp);
        }];
    }
    
    dispatch_group_notify(cgrp, dispatch_get_main_queue(), ^{
        pushHandler(errDict.count > 0 ? errDict : nil);
    });
}

- (void)pullFromRemoteWithCompletionHandler:(void (^)(NSDictionary *errDict))pullHandler
{
    NSSet *databases = [self databases];
    
    NSMutableDictionary *errDict = [NSMutableDictionary dictionaryWithCapacity:databases.count];
    dispatch_group_t cgrp = dispatch_group_create();
    for (MPDatabase *db in databases)
    {
        dispatch_group_enter(cgrp);
        [db pullFromRemoteWithCompletionHandler:^(NSError *err) {
            if (err) errDict[db.name] = err;
            dispatch_group_leave(cgrp);
        }];
    }
    
    dispatch_group_notify(cgrp, dispatch_get_main_queue(), ^{
        pullHandler(errDict.count > 0 ? errDict : nil);
    });
}

- (void)syncWithCompletionHandler:(void (^)(NSDictionary *errDict))syncHandler
{
    NSSet *databases = [self databases];
    
    NSMutableDictionary *errDict = [NSMutableDictionary dictionaryWithCapacity:databases.count];
    dispatch_group_t cgrp = dispatch_group_create();
    for (MPDatabase *db in databases)
    {
        // skip snapshots if they're not to be synced
        if (db == _snapshotsDatabase && ![self synchronizesSnapshots])
            continue;
        
        dispatch_group_enter(cgrp);
        [db syncWithRemoteWithCompletionHandler:^(NSError *err) {
            if (err) errDict[db.name] = err;
            dispatch_group_leave(cgrp);
        }];
    }
    
    dispatch_group_notify(cgrp, dispatch_get_main_queue(), ^{
        syncHandler(errDict.count > 0 ? errDict : nil);
    });
}

#pragma mark - Listener creation

+ (dispatch_queue_t)packageQueue
{
    static dispatch_queue_t packageQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        packageQueue = dispatch_queue_create("com.piipari.package", 0);
    });
    
    return packageQueue;
}

static NSUInteger packagesOpened = 0;
+ (NSUInteger)packagesOpened
{
    return packagesOpened;
}

+ (void)didOpenPackage
{
    dispatch_sync([self packageQueue], ^{ packagesOpened++; });
}

- (void)startListener
{
    assert(!_databaseListener);
    assert(_server);
    
    __weak MPDatabasePackageController *weakSelf = self;
    [(CouchTouchDBServer *)_server tellTDServer: ^(TD_Server* tds) {
        __strong MPDatabasePackageController *strongSelf = weakSelf;
        [TD_View setCompiler:strongSelf];
        
        NSUInteger port = 10000 + [[strongSelf class] packagesOpened];
        strongSelf.databaseListener = [[TDListener alloc] initWithTDServer:tds port:port];
        
        NSDictionary *txtDict = [strongSelf.databaseListener.TXTRecordDictionary mutableCopy];
        [txtDict setValue:@(port) forKey:@"port"];
        
        NSLog(@"Serving %@ at '%@:%@'", _path, [_server URL], @(port));
        
        strongSelf.databaseListener.TXTRecordDictionary = txtDict;
        [strongSelf.databaseListener start];
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf advertiseListener];
            [self didStartDatabaseListener];
        });
    }];
}

- (void)stopListener
{
    assert(_databaseListener);
    [_databaseListener stop];
}

- (NSUInteger)databaseListenerPort
{
    if (!_databaseListener) return 0;
    return [_databaseListener port];
}

- (BOOL)indexesObjectFullTextContents
{
    return NO;
}

- (NSURL *)databaseListenerURL
{
    return [NSURL URLWithString:
            [NSString stringWithFormat:@"http://%@:%lu",
             [[NSHost currentHost] name], self.databaseListenerPort]];
}

#pragma mark - Listener advertising

- (void)advertiseListener
{
    assert(_databaseListener);
	
	if (_databaseListener.port > 0)
	{
		NSBundle *bundle = [NSBundle mainBundle];
        NSHost   *host = [NSHost currentHost];
        
		NSDictionary *txtRecordDataDict = @{ @"appVersion"    : [bundle bundleVersionString],
                                             @"appIdentifier" : [bundle bundleIdentifier],
                                         @"packageIdentifier" : [self identifier]};
        
		NSData *txtRecordData = [NSNetService dataFromTXTRecordDictionary:txtRecordDataDict];
        NSString *serviceName = [NSString stringWithFormat:@"%@_%@", [host name], [self identifier]];
		_databaseListenerService = [[NSNetService alloc] initWithDomain:@""
                                                           type:@"_Featherlink._tcp."
                                                           name:serviceName
                                                           port:_databaseListener.port];
		assert(_databaseListenerService);
		[_databaseListenerService setTXTRecordData:txtRecordData];
		[_databaseListenerService setDelegate:self];
		[_databaseListenerService publish];
	}
    else
    {
        NSLog(@"ERROR: No listener port to advertise for database package %@", [self identifier]);
    }
}

- (void)netServiceWillPublish:(NSNetService *)sender
{
    MPLog(@"Service for database package %@ will publish.", [self identifier]);
}

- (void)netServiceDidPublish:(NSNetService *)sender
{
    MPLog(@"Service for database package %@ published.", [self identifier]);
}

/* The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration for error code constants). It is possible for an error to occur after a successful publication.
 */
- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
{
    NSLog(@"ERROR: Service for database package %@ failed to publish: %@", sender, errorDict);
}

- (void)netServiceWillResolve:(NSNetService *)service
{
    MPLog(@"Service for database package %@ will resolve.", [self identifier]);
}

/* Sent to the NSNetService instance's delegate when one or more addresses have been resolved for an NSNetService instance. Some NSNetService methods will return different results before and after a successful resolution. An NSNetService instance may get resolved more than once; truly robust clients may wish to resolve again after an error, or to resolve more than once.
 */
- (void)netServiceDidResolveAddress:(NSNetService *)service
{
    MPLog(@"Service for database package %@ resolved address.", [self identifier]);
}

/* Sent to the NSNetService instance's delegate when an error in resolving the instance occurs. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants).
 */
- (void)netService:(NSNetService *)service didNotResolve:(NSDictionary *)errorDict
{
    MPLog(@"Service for database package %@ failed to resolve: %@", [self identifier], errorDict);
}

- (void)netServiceDidStop:(NSNetService *)service
{
    MPLog(@"Service for database package %@ stopped.", [self identifier]);
}

- (void)netService:(NSNetService *)service didUpdateTXTRecordData:(NSData *)data
{
    NSDictionary *info = [NSNetService dictionaryFromTXTRecordData:[service TXTRecordData]];
    MPLog(@"Service for database package %@ updated TXT record: %@", [self identifier], info);
}

#pragma mark - Listener monitoring

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser
{
    MPLog(@"Monitor for database package %@ will search for services.", [self identifier]);
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser
{
    MPLog(@"Net service did stop search.");
}

/* Sent to the NSNetServiceBrowser instance's delegate when an error in searching for domains or services has occurred. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants). It is possible for an error to occur after a search has been started successfully.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict
{
    
}

/* Sent to the NSNetServiceBrowser instance's delegate for each domain discovered. If there are more domains, moreComing will be YES. If for some reason handling discovered domains requires significant processing, accumulating domains until moreComing is NO and then doing the processing in bulk fashion may be desirable.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing
{
    
}

/* Sent to the NSNetServiceBrowser instance's delegate for each service discovered. If there are more services, moreComing will be YES. If for some reason handling discovered services requires significant processing, accumulating services until moreComing is NO and then doing the processing in bulk fashion may be desirable.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    
}

/* Sent to the NSNetServiceBrowser instance's delegate when a previously discovered domain is no longer available.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveDomain:(NSString *)domainString moreComing:(BOOL)moreComing
{
    
}

/* Sent to the NSNetServiceBrowser instance's delegate when a previously discovered service is no longer published.
 */
- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    
}

#pragma mark - Snapshots

- (MPSnapshot *)newSnapshotWithName:(NSString *)name
{
    assert(name);
    assert(_managedObjectsControllers);
    assert(_managedObjectsControllers.count > 1); // snapshots controller itself is included
    
    __block MPSnapshot *snp = nil;
    MPSnapshotsController *sc = self.snapshotsController;
    [sc newSnapshotWithName:name snapshotHandler:^(MPSnapshot *snapshot) {
        
        for (MPManagedObjectsController *moc in _managedObjectsControllers)
        {
            if (moc == sc) continue;
            for (MPManagedObject *mo in [moc allObjects])
            {
                MPSnapshottedObject *so = [[MPSnapshottedObject alloc]
                                           initWithController:sc snapshot:snapshot
                                           snapshottedObject:mo];
                [so save];
            }
        }
        
        snp = snapshot;
    }];
    
    assert(snp != nil);
    return snp;
}

- (BOOL)restoreFromSnapshotWithName:(NSString *)name error:(NSError **)err
{
    MPSnapshotsController *sc = [self snapshotsController];
    MPSnapshot *snapshot = [MPSnapshot modelForDocument:[sc.db.database documentWithID:name]];
    
    if (!snapshot)
    {
        if (err)
            *err = [NSError errorWithDomain:MPDatabasePackageControllerErrorDomain
                                       code:MPDatabasePackageControllerErrorCodeNoSuchSnapshot
                                   userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"No snapshot with name %@ found", name]}];
        return NO;
    }
    
    NSArray *snapshottedObjects = [sc snapshottedObjectsForSnapshot:snapshot];
    
    NSMutableArray *saveableObjects = [NSMutableArray arrayWithCapacity:snapshottedObjects.count];
    for (MPSnapshottedObject *so in snapshottedObjects)
    {
        Class cls = [so snapshottedObjectClass];
        assert([cls isSubclassOfClass:[MPManagedObject class]]);
        assert(![cls isSubclassOfClass:[MPSnapshottedObject class]]);
        
        NSDictionary *props = [so snapshottedProperties];
        
        MPManagedObjectsController *moc = [self controllerForManagedObjectClass:cls];
        assert(moc);
        
        MPManagedObject *mo = [cls modelForDocument:[moc.db.database documentWithID:so.snapshottedDocumentID]];
        assert(mo); // error? ignore silently?
        
        if ([[mo.document currentRevisionID] isEqualToString:so.snapshottedRevisionID] && ![mo needsSave])
        {
            assert([mo.document.properties isEqual:props]); // if revisions and there are no changes, contents should be equal
            continue;
        }
        
        [mo setValuesForPropertiesWithDictionary:props];
    }
    
    if (saveableObjects.count > 0)
        { return [[CouchModel saveModels:saveableObjects] wait]; }
    
    return YES;
}

#pragma mark - View function compilation

- (TDMapBlock)compileMapFunction:(NSString *)mapSource language:(NSString *)language
{
    @throw [NSException exceptionWithName:@"MPUnsupportedLanguageException"
                                   reason:@"View function compilation unsupported." userInfo:nil];
}

- (TDReduceBlock)compileReduceFunction:(NSString *)reduceSource language:(NSString *)language
{
    @throw [NSException exceptionWithName:@"MPUnsupportedLanguageException"
                                   reason:@"View function compilation unsupported." userInfo:nil];
}

+ (NSArray *)orderedRootSectionClassNames { return nil; }

@end

#pragma mark - Protected interface

@implementation MPDatabasePackageController (Protected)

- (void)registerManagedObjectsController:(MPManagedObjectsController *)moc
{
    if (!_managedObjectsControllers)
    {
        _managedObjectsControllers = [NSMutableArray arrayWithCapacity:20];
    }
    
    assert(![_managedObjectsControllers containsObject:moc]);
    [_managedObjectsControllers addObject:moc];
}

- (void)setPulls:(NSMutableArray *)pulls { _pulls = pulls; }
- (NSMutableArray *)pulls { return _pulls; }

- (void)setCompletedPulls:(NSMutableArray *)pulls { _completedPulls = pulls; }
- (NSMutableArray *)completedPulls { return _completedPulls; }

- (void)setPullCompletionHandler:(MPPullCompletionHandler)pullCompletionHandler
{
    _pullCompletionHandler = pullCompletionHandler;
}

- (MPPullCompletionHandler)pullCompletionHandler
{
    return _pullCompletionHandler;
}

- (void)setPrimaryDatabase:(MPDatabase *)primaryDatabase
{
    // if no primary database name is defined, shouldn't try to set one
    if ([[self class] primaryDatabaseName])
    {
        assert(!primaryDatabase);
        return;
    }
    NSString *ivarName = [NSString stringWithFormat:@"_%@Database", [[self class] primaryDatabaseName]];
    Ivar primaryDatabaseIvar = class_getInstanceVariable([self class], [ivarName UTF8String]);
    assert(primaryDatabaseIvar);
    object_setIvar(self, primaryDatabaseIvar, primaryDatabase);
}

- (void)didStartDatabaseListener
{
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd];
}

// default implementation is no-op because the default notification center is used.
- (void)makeNotificationCenter { }


- (void)didChangeDocument:(CouchDocument *)document source:(MPManagedObjectChangeSource)source
{
    // ignore MPMetadata & MPLocalMetadata
    if (!document.properties[@"objectType"]) return;
    
    MPManagedObjectsController *moc = [self controllerForDocument:document];
    assert(moc);
    assert(moc.db.database == document.database);
    
    MPManagedObject *mo = [[document managedObjectClass] modelForDocument:document];
    assert(mo);
    assert([document modelObject] == mo);
    
    [moc didChangeDocument:document forObject:document.modelObject source:source];
}

@end