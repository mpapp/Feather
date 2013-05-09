//
//  MPShoeboxPackageController.m
//  Feather
//
//  Created by Matias Piipari on 29/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPShoeboxPackageController.h"
#import <Feather/NSBundle+MPExtensions.h>
#import <Feather/NSBundle+MPExtensions.h>
#import "MPShoeboxPackageController+Protected.h"
#import "MPDatabasePackageController+Protected.h"
#import "MPDatabase.h"

#import "MPManagedObject+Protected.h"
#import "NSObject+MPExtensions.h"
#import "NSFileManager+MPExtensions.h"
#import "MPException.h"

NSString * const MPDefaultsKeySharedPackageUDID = @"MPDefaultsKeySharedPackageUDID";


@implementation MPShoeboxPackageController

- (instancetype)initWithPath:(NSString *)path delegate:(id<MPDatabasePackageControllerDelegate>)delegate
                       error:(NSError *__autoreleasing *)err
{
    @throw [NSException exceptionWithName:@"MPInvalidInitException"
                                   reason:@"Use -initWithError:" userInfo:nil];
}

- (instancetype)initWithError:(NSError *__autoreleasing *)err
{
    if (self = [super initWithPath:[[self class] sharedDatabasesPath] delegate:nil error:err])
    {
        assert(self.server);
        assert(_sharedDatabase);
        
        NSString *identifier = [_sharedDatabase.metadata getValueOfProperty:@"identifier"];
        NSLog(@"%@", identifier);
        assert(_sharedDatabase.metadata);
        
        if (!identifier)
        {
            [_sharedDatabase.metadata setValue:[[NSUUID UUID] UUIDString] ofProperty:@"identifier"];
            [[[_sharedDatabase metadata] save] wait];
        }
        
        /* The global database is _not_ a TouchDB server but a CouchDB server. */
        
        // wait for possible further subclass initialisation to finish.
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (self.synchronizesWithRemote)
            {
                _globalSharedDatabaseServer
                    = [[CouchServer alloc] initWithURL:[self remoteURL]];
                
                _globalSharedDatabase
                    = [[MPDatabase alloc] initWithServer:_globalSharedDatabaseServer
                                       packageController:self name:[self remoteGlobalSharedDatabaseName]
                                           ensureCreated:NO
                                                   error:err];
                    
                if ([self synchronizesUserData])
                    [self syncWithCompletionHandler:^(NSDictionary *errDict) { }];
                
                
                if ([self sharesUserData])
                {
                    NSURL *url = [self remoteGlobalSharedDatabaseURL];
                    
                    [_sharedDatabase pushPersistentlyToDatabaseAtURL:url
                                                        continuously:YES
                                               withCompletionHandler:^(NSError *err) { }];
                    [_sharedDatabase pullPersistentlyFromDatabaseAtURL:url
                                                          continuously:YES
                                                 withCompletionHandler:^(NSError *err) { }];
                }
            }
        });
    }
    else {
        return nil;
    }
    
    return self;
}

+ (NSString *)udid
{
    static dispatch_once_t onceToken;
    static NSString *udid = nil;
    dispatch_once(&onceToken, ^{
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        
        udid = [defs objectForKey:@"MPDefaultsKeySharedPackageUDID"];
        if (!udid)
        {
            udid = [[NSUUID UUID] UUIDString];
            
            [defs setObject:udid forKey:@"MPDefaultsKeySharedPackageUDID"];
            [defs synchronize];
        }
    });
    
    return udid;
}

+ (NSString *)sharedDatabasesPath
{
    NSFileManager *fm = [NSFileManager defaultManager];
    return [[fm applicationSupportFolder] stringByAppendingPathComponent:[[NSBundle appBundle] bundleNameString]];
}

+ (BOOL)createSharedDatabasesPathWithError:(NSError **)err
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    
    NSString *containingDir = [[self sharedDatabasesPath] stringByDeletingLastPathComponent];
    if ([fm fileExistsAtPath:containingDir isDirectory:&isDir] && isDir &&
        [fm fileExistsAtPath:[self sharedDatabasesPath]]) return YES;
    
    if (!isDir)
    { if (err)
        *err = [NSError errorWithDomain:MPDatabasePackageControllerErrorDomain
                                          code:MPDatabasePackageControllerErrorCodeFileNotDirectory
                                      userInfo:@{NSLocalizedDescriptionKey : @"Directory containig the shared databases path does not exist"}];
        return NO;
    }
    
    if (![fm createDirectoryAtPath:[self sharedDatabasesPath] withIntermediateDirectories:YES attributes:nil error:err])
    {
        return NO;
    }
    
    return YES;
}

#pragma mark - Abstract methods

- (void)initializeBundledData
{
}

- (NSString *)remoteGlobalSharedDatabaseName
{
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

- (NSURL *)remoteGlobalSharedDatabaseURL
{
    return [[self remoteURL] URLByAppendingPathComponent:[self remoteGlobalSharedDatabaseName]];
}

#pragma mark - MPManagedObjectSharingObserver

// observing is set up in the MPManuscriptPackageController end.

- (void)didShareManagedObject:(NSNotification *)notification
{
    MPManagedObject *mo = notification.object;
    assert(mo.controller);
    
    if ([mo formsPrototype])
    {
        [mo.controller prototypeForObject:mo];
    }
}

#pragma mark - Singleton

static Class _shoeboxPackageControllerClass = nil;

+ (void)registerShoeboxPackageControllerClass:(Class)class
{
    assert(!_shoeboxPackageControllerClass);
    
    // is non-nil, and subclass of shoebox controller (and not the abstract base class itself)
    assert(class &&
           [class isSubclassOfClass:[MPShoeboxPackageController class]] &&
           (class != [MPShoeboxPackageController class]));
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shoeboxPackageControllerClass = class;
    });
}

static MPShoeboxPackageController *_sharedInstance = nil;
static dispatch_once_t onceToken;
+ (instancetype)sharedShoeboxController
{
    dispatch_once(&onceToken, ^{
        NSError *err = nil;
        
        assert(_shoeboxPackageControllerClass &&
               [_shoeboxPackageControllerClass isSubclassOfClass:[MPShoeboxPackageController class]] &&
               (_shoeboxPackageControllerClass != [MPShoeboxPackageController class]));
        
        if (![_shoeboxPackageControllerClass createSharedDatabasesPathWithError:&err])
        {
            NSLog(@"ERROR! Could not create shared data directory:\n%@", err);            
        }
        _sharedInstance = [[_shoeboxPackageControllerClass alloc] initWithError:&err];
        if (err)
        {
            NSLog(@"ERROR! Could not initialize shared package controller:\n%@", err);
        }
        assert(_sharedInstance);
    });
    
    return _sharedInstance;
}

+ (BOOL)sharedShoeboxControllerInitialized { return _sharedInstance != nil; }

+ (void)finalizeSharedShoeboxController
{
    [_sharedInstance close];
    onceToken = 0;
    _sharedInstance = nil;
}



#pragma mark - Filtered replication

- (NSString *)pushFilterNameForDatabaseNamed:(NSString *)dbName
{
    if ([dbName isEqualToString:[[self class] primaryDatabaseName]])
        return [[self class] primaryDatabaseName];
    
    return nil;
}

- (NSString *)pullFilterNameForDatabaseNamed:(NSString *)dbName
{
    if ([dbName isEqualToString:[[self class] primaryDatabaseName]])
        return @"shared_managed_objects/accepted";
    
    return nil;
}

- (BOOL)applyFilterWhenPullingFromDatabaseAtURL:(NSURL *)url toDatabase:(MPDatabase *)database
{
    MPDatabase *primaryDB = [self primaryDatabase];
    
    // the primary database is for user only, no filters needed. filter only for the global database.
    if (database == primaryDB && [url isEqualTo:[primaryDB remoteDatabaseURL]]) return NO;
    
    return YES;
}

- (BOOL)applyFilterWhenPushingToDatabaseAtURL:(NSURL *)url fromDatabase:(MPDatabase *)database
{
    // same filtering rule applies for both push and pull
    return [self applyFilterWhenPullingFromDatabaseAtURL:url toDatabase:database];
}

- (TD_FilterBlock)createPushFilterBlockWithName:(NSString *)filterName forDatabase:(MPDatabase *)db{
    assert(filterName);
    assert([filterName isEqualToString:[self pushFilterNameForDatabaseNamed:db.name]]);
    assert(db);
    assert(db == [self primaryDatabase]);
    
    if ([filterName isEqualToString:[self pushFilterNameForDatabaseNamed:db.name]])
    {
        [db defineFilterNamed:filterName block:^BOOL(TD_Revision *revision, NSDictionary *params)
         {
             return [revision.properties[@"shared"] boolValue];
         }];
        
        TD_FilterBlock block = [db filterWithName:filterName];
        assert(block);
        return block;
    }
    
    //assert(false);
    return nil;
}

- (TD_FilterBlock)pushFilterBlockWithName:(NSString *)filterName forDatabase:(MPDatabase *)db
{
    assert(db);
    TD_FilterBlock block = [db filterWithName:filterName];
    if (block) return block;
    
    block = [self createPushFilterBlockWithName:filterName forDatabase:db];
    //assert(block);
    
    return block;
}

@end
