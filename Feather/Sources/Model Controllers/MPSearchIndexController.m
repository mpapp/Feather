
//
//  MPSearchIndexController.m
//  Feather
//
//  Created by Matias Piipari on 07/05/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPSearchIndexController.h"
#import "MPException.h"

#import "MPManagedObject.h"
#import "MPDatabasePackageController.h"

#import "MPTitledProtocol.h"

#import "NSNotificationCenter+MPExtensions.h"
#import "NSObject+MPExtensions.h"

#import "MPManagedObjectsController.h"
#import "MPDatabasePackageController.h"
#import "NSString+MPSearchIndex.h"

#import "NSArray+MPExtensions.h"

#import <FMDatabase.h>
#import <FMResultSet.h>

NSString * const MPSearchIndexControllerErrorDomain = @"MPSearchIndexControllerErrorDomain";

@interface MPSearchIndexController ()
@property (readwrite, weak) MPDatabasePackageController *packageController;
@property (readwrite, strong) CBL_FMDatabase *searchIndexDatabase;
@property (readwrite, strong) dispatch_queue_t indexQueue;
@property (readwrite, strong) NSError *lastError;
@end

@implementation MPSearchIndexController

- (instancetype)init
{
    @throw [[MPInitIsPrivateException alloc] initWithSelector:_cmd];
}

- (instancetype)initWithPackageController:(MPDatabasePackageController *)packageController
{
    if (self = [super init])
    {
        assert(packageController);
        self.packageController = packageController;
        
        _indexQueue = dispatch_queue_create("com.piipari.feather.fts.index", DISPATCH_QUEUE_SERIAL);
        
        // any changed data results in indexing
        for (Class cls in [MPManagedObjectsController managedObjectClasses])
        {
            // skip classes with no indexable property keys.
            if ([cls indexablePropertyKeys].count == 0) continue;
            
            [self.packageController.notificationCenter
             addRecentChangeObserver:self forManagedObjectsOfClass:cls
             hasAdded:^(MPSearchIndexController *_self, NSNotification *notification)
            {
                dispatch_async(_self.indexQueue, ^{
                    NSError *err = nil;
                    if (![_self _indexManagedObject:notification.object error:&err])
                        _self.lastError = err;
                });
            }
             hasUpdated:^(MPSearchIndexController *_self, NSNotification *notification)
            {
                dispatch_async(_self.indexQueue, ^{
                    NSError *err = nil;
                    if (![_self _updateIndexForManagedObject:notification.object error:&err])
                        _self.lastError = err;
                });
            }
             hasRemoved:^(MPSearchIndexController *_self, NSNotification *notification)
            {
                dispatch_async(_self.indexQueue, ^{
                    NSError *err = nil;
                    if (![_self _deleteManagedObjectFromIndex:notification.object error:&err])
                        _self.lastError = err;
                });
            }];
        }
    }
    
    return self;
}

- (void)dealloc
{
    [self.packageController.notificationCenter removeObserver:self];
}

- (NSString *)path
{
    assert(self.packageController.path);
    return [self.packageController.path stringByAppendingPathComponent:@"search-index.fts"];
}

+ (NSDictionary *)errorDictionaryForLastError:(CBL_FMDatabase *)db
{
    return @{@"code":@([db lastErrorCode] ? [db lastErrorCode] : 0), NSLocalizedDescriptionKey:[db lastErrorMessage] ? [db lastErrorMessage] : @""};
}

- (BOOL)ensureCreatedWithError:(NSError **)err
{
    NSFileManager *fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:self.path]) { return YES; }
	
    
    BOOL dbSuccess = YES;
		
    CBL_FMDatabase *db = [CBL_FMDatabase databaseWithPath:self.path];
    
    int flags =  SQLITE_OPEN_FILEPROTECTION_COMPLETEUNLESSOPEN
                 | SQLITE_OPEN_READWRITE
                 | SQLITE_OPEN_CREATE;
    
    dbSuccess = [db openWithFlags:flags];
    
    if (!dbSuccess)
    {
        if (err)
            *err = [NSError errorWithDomain:MPSearchIndexControllerErrorDomain
                                       code:MPSearchIndexControllerErrorCodeOpenFailed
                                   userInfo:[[self class] errorDictionaryForLastError:db]];
        return NO;
    }
    
	dbSuccess = [db executeUpdate:
                    @"CREATE VIRTUAL TABLE IF NOT EXISTS search_data USING FTS4 (_id, objectType, title, desc, contents)"];
    
    if (!dbSuccess)
    {
        if (err)
            *err = [NSError errorWithDomain:MPSearchIndexControllerErrorDomain
                                       code:MPSearchIndexControllerErrorCodeVirtualTableCreationFailed userInfo:nil];
        return NO;
    }
    
    self.searchIndexDatabase = db;
    
    return YES;
}

- (void)indexManagedObjects:(NSArray *)objects error:(NSError *__autoreleasing *)err
{
    return [self _indexManagedObjects:objects error:err];
}

- (void)_indexManagedObjects:(NSArray *)objects error:(NSError **)err
{
    BOOL successful = YES;
    
    #warning re-introduce transaction support.
    //[self.searchIndexDatabase beginTransaction];
    
    {
        for (MPManagedObject *mo in objects)
        {
            if ((successful = [self _indexManagedObject:mo error:err]))
                break;
        }
    }
    
    #warning re-introduce transaction support.
    //if (!successful)
    //    [self.searchIndexDatabase rollback];
    //else
    //    [self.searchIndexDatabase commit];
}

- (BOOL)indexManagedObject:(MPManagedObject *)object error:(NSError *__autoreleasing *)err
{
    return [self _indexManagedObject:object error:err];
}

- (BOOL)_indexManagedObject:(MPManagedObject *)object error:(NSError **)err
{
    BOOL dbSuccess = YES;
    
    BOOL isTitled = [object conformsToProtocol:@protocol(MPTitledProtocol)];
    
    NSString *title = isTitled ? [object valueForKey:@"title"] : nil;
    NSString *desc = isTitled ? [object valueForKey:@"desc"] : nil;
    NSString *tokenizedString = [object tokenizedFullTextString];
    
    BOOL hasSomethingToTokenize =
        title != nil || desc != nil || tokenizedString != nil;
    
    if (!hasSomethingToTokenize) return YES;
    
    dbSuccess = [self.searchIndexDatabase
                 executeUpdate:
                    @"INSERT INTO search_data (_id, objectType, title, desc, contents) VALUES (?, ?, ?, ?, ?)",
                         object.document.documentID,
                         NSStringFromClass([object class]),
                         title ? title : @"",
                         desc ? desc : @"",
                         tokenizedString ? tokenizedString : @"", nil];
    
    if (!dbSuccess)
    {
        if (err)
            *err = [NSError errorWithDomain:MPSearchIndexControllerErrorDomain
                                       code:MPSearchIndexControllerErrorCodeIndexingObjectFailed
                                   userInfo:[[self class] errorDictionaryForLastError:self.searchIndexDatabase]];
        return NO;
    }
    
    return YES;
}

- (BOOL)_updateIndexForManagedObject:(MPManagedObject *)object error:(NSError **)err
{
    BOOL dbSuccess = YES;
    
    BOOL isTitled = [object conformsToProtocol:@protocol(MPTitledProtocol)];
    
    NSString *title = isTitled ? [object valueForKey:@"title"] : nil;
    NSString *desc = isTitled ? [object valueForKey:@"desc"] : nil;
    NSString *tokenizedString = [object tokenizedFullTextString];
    
    BOOL hasSomethingToTokenize =
    title != nil || desc != nil || tokenizedString != nil;
    
    if (hasSomethingToTokenize)
    {
        dbSuccess = [self.searchIndexDatabase
                         executeUpdate:
                             @"UPDATE search_data SET title = ?, desc = ?, contents = ? WHERE _id = ?",
                                 title ? title : @"",
                     desc ? desc : @"",
                     tokenizedString ? tokenizedString : @"",
                    object.document.documentID, nil];
        
        if (!dbSuccess)
        {
            if (err)
                *err = [NSError errorWithDomain:MPSearchIndexControllerErrorDomain
                                           code:MPSearchIndexControllerErrorCodeReindexingObjectFailed
                                       userInfo:[[self class] errorDictionaryForLastError:self.searchIndexDatabase]];
            return NO;
        }
    }
    else // if no data for the index, delete the record for the _id
    {
        [self _deleteManagedObjectFromIndex:object error:err];
    }
    
    
    return YES;
}

- (BOOL)_deleteManagedObjectFromIndex:(MPManagedObject *)object error:(NSError **)err
{
    assert(object.documentID);
    BOOL success = [self.searchIndexDatabase executeUpdate:@"DELETE FROM search_data WHERE _id = ?", object.documentID];
    
    if (!success && err)
        *err = [NSError errorWithDomain:MPSearchIndexControllerErrorDomain
                                   code:MPSearchIndexControllerErrorCodeDeletionFromIndexFailed
                               userInfo:[[self class] errorDictionaryForLastError:self.searchIndexDatabase]];
    
    return success;
}

- (BOOL)close
{
    __block BOOL success = NO;
    dispatch_sync(_indexQueue, ^{
        assert(self.searchIndexDatabase);
        success = [self.searchIndexDatabase close];
    });
    
    return success;
}

- (NSArray *)objectsForResultSet:(CBL_FMResultSet *)results
{
    NSMutableArray *objects = [NSMutableArray arrayWithCapacity:100];
    while ([results next])
    {
        NSString *objID = [results stringForColumn:@"_id"];
        NSString *objType = [results stringForColumn:@"objectType"];
        
        Class objClass = NSClassFromString(objType);
        MPManagedObjectsController *c = [self.packageController controllerForManagedObjectClass:objClass];
        MPManagedObject *mo = [c objectWithIdentifier:objID];
        
        if (mo) [objects addObject:mo];
        else
        {
            NSLog(@"WARNING! No %@ found with ID '%@'", objType, objID);
        }
    }
    
    return [objects copy];
}

- (NSArray *)objectsWithMatchingTitle:(NSString *)title
{
    assert(title);
    
    __block CBL_FMResultSet *results = nil;
    
    dispatch_sync(_indexQueue, ^{
        results = [self.searchIndexDatabase executeQuery:@"SELECT DISTINCT _id,objectType FROM search_data WHERE search_data MATCH ?"
                                    withArgumentsInArray:@[ title ] ];
    });
    
    return [self objectsForResultSet:results];
}

- (NSArray *)objectsOfManagedObjectClass:(Class)class withMatchingTitle:(NSString *)title
{
    assert([class isSubclassOfClass:[MPManagedObject class]]);
    return [[self objectsWithMatchingTitle:title] filteredArrayMatching:^BOOL(MPManagedObject *obj) {
        return [obj isKindOfClass:class];
    }];
}

- (NSArray *)objectsWithMatchingDesc:(NSString *)desc
{
    assert(desc);
    
    __block CBL_FMResultSet *results = nil;
    
    dispatch_sync(_indexQueue, ^{
        results = [self.searchIndexDatabase executeQuery:
            @"SELECT DISTINCT _id, objectType FROM search_data WHERE desc MATCH ?"
                                    withArgumentsInArray:@[ desc ] ];
    });
    
    
    return [self objectsForResultSet:results];
}

- (NSArray *)objectsOfManagedObjectClass:(Class)class withMatchingDesc:(NSString *)desc
{
    assert([class isSubclassOfClass:[MPManagedObject class]]);
    return [[self objectsWithMatchingDesc:desc] filteredArrayMatching:^BOOL(MPManagedObject *obj) {
        return [obj isKindOfClass:class];
    }];
}

- (NSArray *)objectsWithMatchingContents:(NSString *)contents
{
    assert(contents);
    
    __block CBL_FMResultSet *results = nil;
    
    dispatch_sync(_indexQueue, ^{
        [self.searchIndexDatabase executeQuery:
            @"SELECT DISTINCT _id, objectType FROM search_data WHERE contents MATCH ?"
                          withArgumentsInArray:@[ contents ] ];
    });
    
    return [self objectsForResultSet:results];
}

- (NSArray *)objectsOfManagedObjectClass:(Class)class withMatchingContents:(NSString *)desc
{
    assert([class isSubclassOfClass:[MPManagedObject class]]);
    return [[self objectsWithMatchingContents:desc] filteredArrayMatching:^BOOL(MPManagedObject *obj) {
        return [obj isKindOfClass:class];
    }];
}

- (NSArray *)objectsMatchingQuery:(NSString *)query
{
    __block CBL_FMResultSet *results = nil;
    
    dispatch_sync(_indexQueue, ^{
        results = [self.searchIndexDatabase executeQuery:
                   @"SELECT DISTINCT _id, objectType FROM search_data WHERE search_data MATCH ?"
                                    withArgumentsInArray:@[ query ] ];
    });
    
    return [self objectsForResultSet:results];
}

- (NSArray *)objectsOfManagedObjectClass:(Class)class matchingQuery:(NSString *)query
{
    assert([class isSubclassOfClass:[MPManagedObject class]]);
    return [[self objectsMatchingQuery:query] filteredArrayMatching:^BOOL(MPManagedObject *obj) {
        return [obj isKindOfClass:class];
    }];
}

@end
