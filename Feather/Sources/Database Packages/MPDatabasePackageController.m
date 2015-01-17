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
#import <Feather/NSNotificationCenter+ErrorNotification.h>

#import "MPContributor.h"
#import "MPContributorsController.h"
#import "MPSnapshotsController.h"
#import "MPException.h"
#import "NSString+MPExtensions.h"
#import "NSObject+MPExtensions.h"

#import "MPRootSection.h"

#import "JSONKit.h"

#import "RegexKitLite.h"

#import <Feather/NSObject+MPExtensions.h>

#import <CouchbaseLite/CouchbaseLite.h>
#import <CouchbaseLiteListener/CBLListener.h>

#import <objc/runtime.h>

#import <arpa/inet.h>
#import <net/if.h>
#import <ifaddrs.h>

NSString * const MPDatabasePackageListenerDidStartNotification = @"MPDatabasePackageListenerDidStartNotification";

@interface MPTemporaryDatabasePackageCopyFileManagerDelegate : NSObject <NSFileManagerDelegate>
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

@property (strong, readwrite) CBLListener *databaseListener;
@property (strong, readwrite) NSNetService *databaseListenerService;

@property (strong, readonly) NSMutableSet *registeredViewNames;

@end

@implementation MPDatabasePackageController
@synthesize snapshotsDatabase = _snapshotsDatabase;

- (instancetype)initWithPath:(NSString *)path
                    readOnly:(BOOL)readOnly
                    delegate:(id<MPDatabasePackageControllerDelegate>)delegate
             error:(NSError *__autoreleasing *)err {
    // off-main thread access of MPDatabasePackageController is safe,
    // but initialisation is needed on main thread in order to call -didInitialize safely
    // after full initialization has finished
    assert([NSThread isMainThread]);
    
    if (self = [super init])
    {
        assert(path);
        
        _path = path;
        
        _delegate = delegate;
        
        _controllerDictionary = [NSMutableDictionary dictionaryWithCapacity:20];
        
        [self makeNotificationCenter];

        CBLManagerOptions opts;
        opts.readOnly = NO;
        
        NSScanner *scanner = [NSScanner scannerWithString:[[NSUUID UUID] UUIDString]];
        [scanner scanHexLongLong:&_serverQueueToken];
        
        _server = [[CBLManager alloc] initWithDirectory:_path options:&opts error:err];
        objc_setAssociatedObject(_server, "dbp", self, OBJC_ASSOCIATION_ASSIGN);
        
        _server.dispatchQueue = mp_dispatch_queue_create(_path, _serverQueueToken, DISPATCH_QUEUE_SERIAL);
        _server.etagPrefix = [[NSUUID UUID] UUIDString]; // TODO: persist the etag inside the package for added performance (this gives predictable behaviour: every app start effectively clears the cache).
        
        [_server.customHTTPHeaders addEntriesFromDictionary:[self databaseListenerHTTPHeaders]];
        
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
            if (!db) {
                return nil;
            }
            [self setValue:db forKey:[NSString stringWithFormat:@"%@Database", db.name]];
            
            if (pushFilterName)
            {
                CBLFilterBlock filterBlock
                    = [self pushFilterBlockWithName:pushFilterName forDatabase:db];
                [db defineFilterNamed:pushFilterName block:filterBlock];
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
                                                                                      database:self.primaryDatabase error:err];
        if (!_contributorsController)
            return nil;
        
        assert(_snapshotsDatabase);
        _snapshotsController
            = [[MPSnapshotsController alloc] initWithPackageController:self database:_snapshotsDatabase error:err];
        if (!_snapshotsController)
            return nil;
        
        _pulls = [[NSMutableArray alloc] initWithCapacity:[[[self class] databaseNames] count]];
        _completedPulls = [[NSMutableArray alloc] initWithCapacity:[[[self class] databaseNames] count]];
        
        if (![NSBundle isCommandLineTool] && // FIXME: manuel will need to serve static resources to equation compilers somehow
            ![NSBundle isXPCService] &&
            [self synchronizesPeerlessly])
        {
            [self startListenerWithCompletionHandler:^(NSError *err)
            {
                [self.notificationCenter postNotificationName:MPDatabasePackageListenerDidStartNotification object:self];
            }];
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
        
        _registeredViewNames = [NSMutableSet setWithCapacity:128];
        
        [[self class] didOpenPackage];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.class registerDatabasePackageController:self];
        });
    }
    
    return self;
}

- (NSDictionary *)databaseListenerHTTPHeaders {
    return @{
             @"Access-Control-Allow-Origin"      : @"*",
             @"Access-Control-Allow-Credentials" : @"false",
             @"Access-Control-Allow-Methods"     : @"GET, POST, PUT, DELETE, OPTIONS",
             @"Access-Control-Allow-Headers"     : @"Origin, X-CSRFToken, Content-Type, Accept",
             @"Pragma"                           : @"no-cache",
             @"Cache-Control"                    : @"no-cache"
    };
}

+ (NSMapTable *)databasePackageControllerRegistry
{
    static NSMapTable *reg = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        reg = [NSMapTable strongToWeakObjectsMapTable];
    });
               
    return reg;
}

+ (void)registerDatabasePackageController:(MPDatabasePackageController *)packageController
{
    // there should not be two or more database package controllers that are identical in memory at the same time.
    // for instance, if a package controller is duplicated, its identifier should be modified.
    NSParameterAssert(![[self databasePackageControllerRegistry] objectForKey:packageController.fullyQualifiedIdentifier]);
    [self.databasePackageControllerRegistry setObject:packageController forKey:packageController.fullyQualifiedIdentifier];
}

+ (void)deregisterDatabasePackageController:(MPDatabasePackageController *)packageController
{
    [self.databasePackageControllerRegistry removeObjectForKey:packageController.identifier];
}

+ (MPDatabasePackageController *)databasePackageControllerWithFullyQualifiedIdentifier:(NSString *)identifier
{
    NSAssert([identifier containsString:@"::"],
             @"Identifier '%@' does not look like a fully qualified identifier.", identifier);
    return [self.databasePackageControllerRegistry objectForKey:identifier];
}

- (void)dealloc
{
    // db should not be observing notifications after its package controller is deallocated.
    for (MPDatabase *db in self.databases)
    {
        // work on these queues guaranteed to complete before deallocation
        mp_dispatch_sync(db.database.manager.dispatchQueue, [self serverQueueToken], ^{ });
        
        [self.notificationCenter removeObserver:db];
    }
    [self.class deregisterDatabasePackageController:self];
}

- (BOOL)synchronizesSnapshots { return NO; }

- (BOOL)synchronizesWithRemote { return NO; }

- (BOOL)synchronizesPeerlessly { return YES; }

- (BOOL)controllerExistsForManagedObjectClass:(Class)class
{
    return [self _controllerForManagedObjectClass:class] != nil;
}

+ (NSString *)controllerPropertyNameForManagedObjectClass:(Class)cls {
    assert([cls isSubclassOfClass:[MPManagedObject class]]);
    
    NSString *className = NSStringFromClass(cls);
    return [NSString stringWithFormat:@"%@Controller",
            [[[className stringByReplacingOccurrencesOfRegex:
               @"^MP" withString:@""] pluralizedString] camelCasedString]];
}

+ (NSString *)controllerPropertyNameForManagedObjectControllerClass:(Class)cls {
    assert([cls isSubclassOfClass:MPManagedObjectsController.class]);
    return [[NSStringFromClass(cls) stringByReplacingOccurrencesOfRegex:@"^MP" withString:@""] camelCasedString];
}

- (MPManagedObjectsController *)controllerForManagedObjectClass:(Class)class
{
    MPManagedObjectsController *c = [self _controllerForManagedObjectClass:class];
    if (c)
        return c;
    
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
    NSParameterAssert(class);
    NSAssert([class isSubclassOfClass:[MPManagedObject class]] && class != [MPManagedObject class],
             @"Unexpected class: %@", class);
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
        NSString *mocProperty = [MPDatabasePackageController controllerPropertyNameForManagedObjectClass:class];
        
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
        
        for (Class cls in [MPManagedObject.subclasses arrayByAddingObject:class]) {
            Class controllerClass = [self _controllerClassForManagedObjectClass:cls];
            
            if (controllerClass)
                dict[NSStringFromClass(cls)] = controllerClass;
        }
        controllerDictionary = [dict copy];
    });
    
    return controllerDictionary[NSStringFromClass(class)];
}

- (MPManagedObjectsController *)controllerForDocument:(CBLDocument *)document
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

- (id)objectWithIdentifier:(NSString *)identifier {
    NSParameterAssert(identifier);
    
    Class moClass = [MPManagedObject managedObjectClassFromDocumentID:identifier];
    MPManagedObjectsController *moc = [self controllerForManagedObjectClass:moClass];
    MPManagedObject *mo = [moc objectWithIdentifier:identifier];
    
    return mo;
}

- (NSNotificationCenter *)notificationCenter
{
    return [NSNotificationCenter defaultCenter]; // subclass can provide its own notification center
}

#pragma mark - Temporary copy creation

// TODO: replace BOOL flags with a option bits argument, include a sync-by-overwriting-differing-contained-items option (for updates of the bundled shared stuff)
- (BOOL)makeTemporaryCopyIntoRootDirectoryWithURL:(NSURL *)rootURL
                                overwriteIfExists:(BOOL)overwrite
                                     failIfExists:(BOOL)failIfExists
                                            error:(NSError *__autoreleasing *)error
{
    if (!rootURL)
        return NO;

    if (error)
        *error = nil;
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    BOOL isDirectory, exists = [fm fileExistsAtPath:rootURL.path isDirectory:&isDirectory];
    
    if (exists) {
        if (!overwrite) {
            if (error && failIfExists) {
                if (!isDirectory) {
                    *error = [NSError errorWithDomain:MPDatabasePackageControllerErrorDomain
                                                 code:MPDatabasePackageControllerErrorCodeFileNotDirectory
                                             userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"File at '%@' is not a directory", rootURL.path]}];
                }
                else {
                    *error = [NSError errorWithDomain:MPDatabasePackageControllerErrorDomain
                                                 code:MPDatabasePackageControllerErrorCodeDirectoryAlreadyExists
                                             userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Directory at '%@' already exists", rootURL.path]}];
                }
                return NO;
            }
            
            MPLog(@"Temporary directory at '%@' already exists, will do nothing, as instructed", rootURL.path);
            return YES;
        }
    }
    
    if (exists && overwrite)
    {
        BOOL success = [fm removeItemAtURL:rootURL error:error];
        MPLog(@"Failed to remove existing temporary directory at '%@'", rootURL.path);
        if (!success)
            return NO;
        exists = NO;
    }
    
    if (!exists)
    {
        BOOL success = [fm createDirectoryAtURL:rootURL withIntermediateDirectories:YES attributes:nil error:error];
        if (!success)
        {
            MPLog(@"Failed to create temporary directory '%@'", rootURL.path);
            return NO;
        }
    }
    
    
    MPTemporaryDatabasePackageCopyFileManagerDelegate *fmDelegate = [[MPTemporaryDatabasePackageCopyFileManagerDelegate alloc] init];
    fm.delegate = fmDelegate;
    
    NSArray *contents = [fm contentsOfDirectoryAtPath:self.path error:error];
    if (!contents)
    {
        MPLog(@"Failed to get contents of directory '%@': %@", self.path, error ? *error : nil);
        return NO;
    }
    
    for (NSString *filename in contents)
    {
        NSURL *sourceURL = [[NSURL fileURLWithPath:self.path] URLByAppendingPathComponent:filename];
        NSURL *targetURL = [rootURL URLByAppendingPathComponent:filename];
        
        BOOL success = [fm copyItemAtURL:sourceURL toURL:targetURL error:error];
        if (!success)
        {
            MPLog(@"Failed to copy '%@' into '%@': %@", sourceURL.path, targetURL, error ? *error : nil);
            return NO;
        }
    }
    
    return YES;
}

#pragma mark - Databases

- (NSSet *)databases
{
    NSParameterAssert(_managedObjectsControllers);
    NSParameterAssert(_managedObjectsControllers.count);
    
    NSMutableSet *set = [NSMutableSet setWithCapacity:_managedObjectsControllers.count];
    
    for (MPManagedObjectsController *moc in _managedObjectsControllers)
        [set addObject:moc.db];
    
    return [set copy];
}

- (NSArray *)orderedDatabases
{
    return [self.databases.allObjects sortedArrayUsingComparator:^NSComparisonResult(MPDatabase *a, MPDatabase *b) {
        return [a.name compare:b.name];
    }];
}

- (NSSet *)databaseNames
{
    return [self.databases valueForKey:@"name"];
}

- (NSDictionary *)databasesByName
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:self.databases.count];
    for (MPDatabase *db in self.databases)
        dict[db.name] = db;
    return [dict copy];
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
    NSParameterAssert(_managedObjectsControllers);
    // multiple MOCs can be connected to the same database.
    NSSet *databases = [_managedObjectsControllers valueForKey:@"db"];
    
    NSParameterAssert(_managedObjectsControllers);
    NSParameterAssert(databases.count > 0);
    
    [self.databaseListener stop];
    
    for (MPDatabase *db in databases) {
        mp_dispatch_sync(db.server.dispatchQueue, [db.packageController serverQueueToken], ^{
            [db.server close];
        });
    }
}

#pragma mark - Filter functions

- (NSString *)pushFilterNameForDatabaseNamed:(NSString *)dbName
{
    return nil;
}

- (CBLFilterBlock)createPushFilterBlockWithName:(NSString *)filterName forDatabase:(MPDatabase *)db
{
    assert(!filterName);
    return nil;
}

- (CBLFilterBlock)pushFilterBlockWithName:(NSString *)filterName forDatabase:(MPDatabase *)db
{
    assert(db);
    CBLFilterBlock block = [db filterWithQualifiedName:filterName];
    if (block)
        return block;

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

- (NSURL *)remoteURL {
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; return nil;
    return nil;
}

- (NSURL *)remoteServiceURL {
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; return nil;
}

- (NSURL *)remoteDatabaseURLForLocalDatabase:(MPDatabase *)database {
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; return nil;
}

- (NSURL *)remoteServiceURLForLocalDatabase:(MPDatabase *)database {
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; return nil;
}

- (NSString *)identifier {
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; return nil;
}
                                          
- (NSString *)fullyQualifiedIdentifier {
    return [self.path stringByAppendingFormat:@"::%@", self.identifier];
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

- (BOOL)pushToRemoteWithErrorDictionary:(NSDictionary **)errorDict
{
    NSSet *databases = [self databases];
    
    NSMutableDictionary *errDict
        = [NSMutableDictionary dictionaryWithCapacity:databases.count];
    
    for (MPDatabase *db in databases)
    {
        NSError *err = nil;
        if (![db pushToRemote:nil error:&err])
            errDict[db.name] = err;
    }
    
    if (errorDict)
        *errorDict = errDict;
    
    return errDict.count == 0;
}

- (void)pullFromRemoteWithErrorDictionary:(NSDictionary **)errorDict
{
    NSSet *databases = [self databases];
    
    NSMutableDictionary *errDict = [NSMutableDictionary dictionaryWithCapacity:databases.count];
    
    for (MPDatabase *db in databases)
    {
        NSError *err = nil;
        if (![db pullFromRemote:nil error:&err])
            errDict[db.name] = err;
    }
    
    if (errorDict)
        *errorDict = errDict;
}

- (BOOL)syncWithRemote:(NSDictionary **)errorDict
{
    NSSet *databases = [self databases];
    
    NSMutableDictionary *errDict = [NSMutableDictionary dictionaryWithCapacity:databases.count];
    
    for (MPDatabase *db in databases)
    {
        // skip snapshots if they're not to be synced
        if (db == _snapshotsDatabase && ![self synchronizesSnapshots])
            continue;
        
        NSError *err = nil;
        if (![db syncWithRemote:&err])
            errDict[db.name] = err;
    }
    
    if (errorDict)
        *errorDict = errDict;
    
    return errDict.count == 0;
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
    dispatch_sync([self packageQueue], ^{
        packagesOpened++;
    });
}

static const NSUInteger MPDatabasePackageListenerMaxRetryCount = 10;

- (void)startListenerWithCompletionHandler:(void(^)(NSError *err))completionHandler
{
    assert(![NSBundle isCommandLineTool]); // FIXME: this is not correct, as manuel will need to serve static resources to the equation compilers (and no main process is running)
    assert(![NSBundle isXPCService]);
    
    assert(!_databaseListener);
    assert(_server);
    
    __weak MPDatabasePackageController *weakSelf = self;
    
    [_server doAsync:^{
        __strong MPDatabasePackageController *strongSelf = weakSelf;
        
        [CBLView setCompiler:strongSelf];
        
        NSUInteger port = [strongSelf fixedDatabasePort];
        if (port == 0)
            port = 10000 + [[strongSelf class] packagesOpened];
        
        NSError *e = nil;
        NSUInteger retries = 0;
        do {
            e = nil;
            port += retries;
            
            strongSelf.databaseListener = [[CBLListener alloc] initWithManager:_server port:port];
            
            NSDictionary *txtDict = [strongSelf.databaseListener.TXTRecordDictionary mutableCopy];
            [txtDict setValue:@(port) forKey:@"port"];
            
            NSLog(@"Serving %@ at '%@:%@'", _path, _server.internalURL, @(port));
            
            strongSelf.databaseListener.TXTRecordDictionary = txtDict;
            
            if (![strongSelf.databaseListener start:&e]) {
                assert(e);
                retries++;
                continue;
            }
            else {
                e = nil; // success -- let's set the previous error to nil
            }
            
        } while (e && retries < MPDatabasePackageListenerMaxRetryCount);
        
        if (e) {
            [self.notificationCenter postErrorNotification:e];
            completionHandler(e);
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf advertiseListener];
            [self didStartManuscriptsPackageListener];
            completionHandler(nil);
        });
    }];
}

- (void)stopListener
{
    assert(_databaseListener);
    [_databaseListener stop];
}

- (NSUInteger)fixedDatabasePort
{
    return 0;
}

- (NSUInteger)databaseListenerPort
{
    if (!_databaseListener)
        return 0;
    
    NSUInteger port = [_databaseListener port];
    return port;
}

- (BOOL)indexesObjectFullTextContents
{
    return NO;
}

- (NSURL *)databaseListenerURL
{
    NSURL *URL = [NSURL URLWithString:
            [NSString stringWithFormat:@"http://%@:%lu",
             [[NSHost currentHost] name], self.databaseListenerPort]];
    return URL;
}

#pragma mark - Listener advertising

- (void)advertiseListener
{
    assert(_databaseListener);
	
	if (_databaseListener.port > 0)
	{
		NSBundle *bundle = [NSBundle appBundle];
        NSHost   *host = [NSHost currentHost];
        
		NSDictionary *txtRecordDataDict = @{ @"appVersion"    : [[bundle bundleVersionString] dataUsingEncoding:NSUTF8StringEncoding],
                                             @"appIdentifier" : [[bundle bundleIdentifier] dataUsingEncoding:NSUTF8StringEncoding],
                                         @"packageIdentifier" : [[self identifier] dataUsingEncoding:NSUTF8StringEncoding]};
        
		NSData *txtRecordData = [NSNetService dataFromTXTRecordDictionary:txtRecordDataDict];
        NSString *serviceName = [NSString stringWithFormat:@"%@_%@", [host name], [self identifier]];
		_databaseListenerService = [[NSNetService alloc] initWithDomain:@""
                                                           type:@"_Featherlink._tcp."
                                                           name:serviceName
                                                           port:_databaseListener.port];
		assert(_databaseListenerService);
		BOOL success = [_databaseListenerService setTXTRecordData:txtRecordData];
        assert(success);
		[_databaseListenerService setDelegate:self];
		[_databaseListenerService publishWithOptions:NSNetServiceNoAutoRename];
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
    MPLog(@"Service for database package %@ published at port %lu.", [self identifier], [sender port]);
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

- (MPSnapshot *)newSnapshotWithName:(NSString *)name error:(NSError **)err
{
    NSParameterAssert(name);
    NSParameterAssert(_managedObjectsControllers);
    NSParameterAssert(_managedObjectsControllers.count > 1); // snapshots controller itself is included
    
    __block MPSnapshot *snp = nil;
    MPSnapshotsController *sc = self.snapshotsController;
    [sc newSnapshotWithName:name snapshotHandler:^(MPSnapshot *snapshot, NSError *e) {
        if (e)
            return;
        
        for (MPManagedObjectsController *moc in _managedObjectsControllers) {
            if (moc == sc) continue;
            for (MPManagedObject *mo in [moc allObjects])
            {
                MPSnapshottedObject *so = [[MPSnapshottedObject alloc]
                                           initWithController:sc snapshot:snapshot
                                           snapshottedObject:mo];
                if (![so save:err])
                    return;
            }
        }
        
        snp = snapshot;
    }];
    
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
        
        MPManagedObject *mo = [cls modelForDocument:[moc.db.database documentWithID:so.snapshottedObject.documentID]];
        assert(mo); // error? ignore silently?
        
        if ([[mo.document currentRevisionID] isEqualToString:so.snapshottedRevisionID] && ![mo needsSave])
        {
            assert([mo.document.properties isEqual:props]); // if revisions and there are no changes, contents should be equal
            continue;
        }
        
        [mo setValuesForPropertiesWithDictionary:props];
    }
    
    if (saveableObjects.count > 0)
        return [CBLModel saveModels:saveableObjects error:err];
    
    return YES;
}

#pragma mark - View function compilation

- (CBLMapBlock)compileMapFunction:(NSString *)mapSource language:(NSString *)language
{
    @throw [NSException exceptionWithName:@"MPUnsupportedLanguageException"
                                   reason:@"View function compilation unsupported." userInfo:nil];
}

- (CBLReduceBlock)compileReduceFunction:(NSString *)reduceSource
                               language:(NSString *)language
{
    @throw [NSException exceptionWithName:@"MPUnsupportedLanguageException"
                                   reason:@"View function compilation unsupported." userInfo:nil];
}

+ (NSArray *)orderedRootSectionClassNames { return nil; }

#pragma mark - Scripting

- (NSSet *)managedObjectsControllers {
    return _managedObjectsControllers.copy;
}

- (NSScriptObjectSpecifier *)objectSpecifier {
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}


#pragma mark - Dictionary representations

- (BOOL)saveToURL:(NSURL *)URL error:(NSError *__autoreleasing *)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![self saveManifestDictionary:error])
        return NO;
    
    if (![self saveDictionaryRepresentation:error])
        return NO;
    
    for (MPDatabase *db in self.databases)
        dispatch_suspend(db.database.manager.dispatchQueue);
    
    BOOL success = [fm copyItemAtURL:[NSURL fileURLWithPath:self.path] toURL:URL error:error];
    
    for (MPDatabase *db in self.databases)
        dispatch_resume(db.database.manager.dispatchQueue);
    
    return success;
}

- (NSURL *)URL {
    return [NSURL fileURLWithPath:self.path];
}

- (NSURL *)relativePreviewURL {
    return [[NSURL URLWithString:@"QuickLook"] URLByAppendingPathComponent:@"preview.pdf"];
}

- (NSURL *)relativeThumbnailURL {
    return [[NSURL URLWithString:@"QuickLook"] URLByAppendingPathComponent:@"thumbnail.pdf"];
}

- (NSURL *)absolutePreviewURL {
    return [self.URL URLByAppendingPathComponent:self.relativePreviewURL.path];
}

- (NSURL *)absoluteThumbnailURL {
    return [self.URL URLByAppendingPathComponent:self.relativeThumbnailURL.path];
}

- (BOOL)saveManifestDictionary:(NSError **)error {
    return [self.manifestDictionary writeToURL:self.manifestDictionaryURL atomically:YES];
}

- (NSURL *)manifestDictionaryURL {
    return [[NSURL fileURLWithPath:self.path] URLByAppendingPathComponent:@"manifest.json"];
}

- (NSDictionary *)manifestDictionary {
    return @{};
}

- (NSURL *)dictionaryRepresentationURL {
    return [[NSURL fileURLWithPath:self.path] URLByAppendingPathComponent:@"dictionary.json"];
}

- (BOOL)saveDictionaryRepresentation:(NSError **)error {
    return [self.dictionaryRepresentation writeToURL:self.dictionaryRepresentationURL atomically:YES];
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    
    for (MPDatabase *db in self.databases) {
        NSMutableArray *objs = [NSMutableArray new];
        
        for (CBLQueryRow *docRow in db.database.createAllDocumentsQuery.run) {
            CBLDocument *doc = docRow.document;
            if (doc)
                [objs addObject:docRow.document.properties];
        }
        
        dict[db.name] = objs.copy;
    }
    
    return dict.copy;
}

@end

#pragma mark - Protected interface

@implementation MPDatabasePackageController (Protected)

- (void)registerManagedObjectsController:(MPManagedObjectsController *)moc
{
    if (!_managedObjectsControllers)
    {
        _managedObjectsControllers = [NSMutableSet setWithCapacity:20];
    }
    
    assert(![_managedObjectsControllers containsObject:moc]);
    [_managedObjectsControllers addObject:moc];
}

- (void)registerViewName:(NSString *)viewName
{
    assert(![_registeredViewNames containsObject:viewName]);
    [_registeredViewNames addObject:viewName];
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

- (void)didStartManuscriptsPackageListener
{
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd];
}

// default implementation is no-op because the default notification center is used.
- (void)makeNotificationCenter { }


- (void)didChangeDocument:(CBLDocument *)document source:(MPManagedObjectChangeSource)source
{
    // ignore MPMetadata & MPLocalMetadata
    if (!document.properties[@"objectType"])
        return;
    
    MPManagedObjectsController *moc = [self controllerForDocument:document];
    assert(moc);
    assert(moc.db.database == document.database);
    
    MPManagedObject *mo = [[document managedObjectClass] modelForDocument:document];
    assert(mo);
    assert([document modelObject] == mo);
    
    [moc didChangeDocument:document forObject:(id)document.modelObject source:source];
}


@end