//
//  MPManagedObjectsController.m
//  Feather
//
//  Created by Matias Piipari on 16/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Feather/NSBundle+MPExtensions.h>

#import <Feather/MPManagedObject+Protected.h>
#import "MPManagedObjectsController+Protected.h"
#import "MPDatabasePackageController+Protected.h"

#import "NSSet+MPExtensions.h"
#import "NSObject+MPExtensions.h"
#import "NSArray+MPExtensions.h"
#import "NSNotificationCenter+ErrorNotification.h"
#import "NSDictionary+MPExtensions.h"
#import "NSDictionary+MPManagedObjectExtensions.h"
#import "NSString+MPExtensions.h"
#import "NSFileManager+MPExtensions.h"
#import "MPException.h"
#import "MPDatabase.h"

#import "JSONKit.h"
#import "RegexKitLite.h"
#import <CouchbaseLite/CouchbaseLite.h>

#import "Mixin.h"
#import "MPCacheableMixin.h"

#import <objc/runtime.h>
#import <objc/message.h>

extern NSComparisonResult CBLCompareRevIDs(NSString* revID1, NSString* revID2);

NSString * const MPManagedObjectsControllerErrorDomain = @"MPManagedObjectsControllerErrorDomain";

NSString * const MPManagedObjectsControllerLoadedBundledResourcesNotification = @"MPManagedObjectsControllerLoadedBundledResourcesNotification";

@interface MPManagedObjectsController ()
{
    NSSet *_managedObjectSubclasses;
    dispatch_queue_t _queryQueue;
}
@property (readonly, strong) NSMutableDictionary *objectCache;
@end

@implementation MPManagedObjectsController

+ (void)initialize
{
    if (self == [MPManagedObjectsController class])
    {
        [self mixinFrom:[MPCacheableMixin class] followInheritance:NO force:NO];
    }
}

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"MPInvalidInitException" reason:nil userInfo:nil];
    return nil;
}

- (instancetype)initWithPackageController:(MPDatabasePackageController *)packageController
                                 database:(MPDatabase *)db
                                    error:(NSError **)err
{
    // MPManagedObjectsController is abstract
    assert([self class] != [MPManagedObjectsController class]);
    
    if (self = [super init])
    {
        assert(db);
        
        _queryQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.queue",
                                              NSStringFromClass([self class])] UTF8String],
                                            DISPATCH_QUEUE_SERIAL);

        _packageController = packageController;
        _db = db;
        
        _objectCache = [NSMutableDictionary dictionaryWithCapacity:1000];
        
        [packageController registerManagedObjectsController:self];
        
        [self configureViews];
        
        if ([self observesManagedObjectChanges])
        {
            NSNotificationCenter *nc = [packageController notificationCenter];
            
            [nc addRecentChangeObserver:self
             forManagedObjectsOfClass:[self managedObjectClass]
                            hasAdded:
             ^(MPManagedObjectsController *_self, NSNotification *notification)
            {
                [_self hasAddedManagedObject:notification.object];
            }
            hasUpdated:
             ^(MPManagedObjectsController *_self, NSNotification *notification)
            {
                [_self hasUpdatedManagedObject:notification.object];
            }
            hasRemoved:
             ^(MPManagedObjectsController *_self, NSNotification *notification)
            {
                [_self hasRemovedManagedObject:notification.object];
            }];
        }
        
        [self loadBundledResourcesWithCompletionHandler:^(NSError *err) {
            if (err)
                [[self.packageController notificationCenter] postErrorNotification:err];
        }];
    }

    return self;
}

- (void)dealloc
{
    //assert([_packageController notificationCenter]);
    [[_packageController notificationCenter] removeObserver:self];
}

+ (NSArray *)managedObjectClasses
{
    static NSArray *classArray = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,
    ^{
        NSArray *subclasses = [NSObject subclassesForClass:[MPManagedObject class]];
        NSUInteger subclassCount = subclasses.count;
        NSMutableArray *a = [NSMutableArray arrayWithCapacity:subclassCount];
        for (Class subclass in subclasses)
        {
            [a addObject:subclass];
        }
        classArray = [a copy];
    });
    return classArray;
}

+ (NSArray *)managedObjectClassNames
{
    static NSArray *classnameArray = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *classes = [self managedObjectClasses];
        NSMutableArray *classNames = [NSMutableArray arrayWithCapacity:classes.count];
        for (Class subclass in classes)
        {
            [classNames addObject:NSStringFromClass(subclass)];
        }
        classnameArray = [classNames copy];
    });
    
    return classnameArray;
}

+ (NSDictionary *)managedObjectClassByControllerClassNameDictionary
{
    static NSDictionary *classDict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *moClasses = [self managedObjectClassNames];
        NSMutableDictionary *controllers = [NSMutableDictionary dictionaryWithCapacity:moClasses.count];
        for (NSString *className in moClasses)
        {
            assert(NSClassFromString(className));
            NSString *controllerClassName = [NSString stringWithFormat:@"%@Controller", [className pluralizedString]];
            controllers[controllerClassName] = NSClassFromString(className);
        }
        classDict = [controllers copy];
    });
    
    return classDict;
}

+ (Class)managedObjectClass
{
    return [self managedObjectClassByControllerClassNameDictionary][NSStringFromClass(self)];
}

+ (NSString *)managedObjectClassName
{
    return NSStringFromClass([self managedObjectClass]);
}

- (Class)managedObjectClass
{
    Class moClass = [[self class] managedObjectClass];
    assert(moClass);
    assert([moClass isSubclassOfClass:[MPManagedObject class]]);
    return moClass;
}

- (NSSet *)managedObjectSubclasses
{
    if ([self class] == [MPManagedObjectsController class])
        @throw [[MPAbstractClassException alloc] initWithClass:[self class]];
    
    if (!_managedObjectSubclasses)
    {
        Class cls = [self managedObjectClass];
        
        // collate all subclasses of the class
        NSMutableSet *subclassSet = [NSMutableSet setWithCapacity:20];
        NSMutableArray *subclasses = [[NSObject subclassesForClass:cls] mutableCopy];
        
        NSLog(@"Subclasses of %@: %@", NSStringFromClass(cls), subclasses);
        
        [subclassSet addObject:cls];
        [subclassSet addObjectsFromArray:subclasses];
        
        while (subclasses.count > 0)
        {
            Class subcls = [subclasses firstObject];
            [subclassSet addObjectsFromArray:[NSObject subclassesForClass:subcls]];
            [subclasses removeObject:subcls];
        }
        
        _managedObjectSubclasses = [subclassSet mapObjectsUsingBlock:^id(Class class) {
            return NSStringFromClass(class);
        }];
    }
    
    return _managedObjectSubclasses;
}

- (BOOL)managesDocumentWithDictionary:(NSDictionary *)CBLDocumentDict
{
    NSString *objectType = [CBLDocumentDict managedObjectType];
    
    if (!objectType) return NO;
    return [self.managedObjectSubclasses containsObject:objectType];
}

- (BOOL)managesObjectsOfClass:(Class)class
{
    return [self.managedObjectSubclasses containsObject:NSStringFromClass(class)];
}

- (CBLMapBlock)allObjectsBlock
{
    return ^(NSDictionary *doc, CBLMapEmitBlock emit)
    {
        if (![self managesDocumentWithDictionary:doc]) return;
        emit(doc[@"_id"], nil);
    };
}

- (CBLMapBlock)bundledObjectsBlock
{
    return ^(NSDictionary *doc, CBLMapEmitBlock emit)
    {
        if (![self managesDocumentWithDictionary:doc]) return;
        if (![doc[@"bundled"] boolValue]) return;
        
        emit(doc[@"_id"], nil);
    };
}

- (NSString *)managedObjectClassName
{ return [[self class] managedObjectClassName]; }

#pragma mark - Prototyping

- (MPManagedObject *)prototypeForObject:(MPManagedObject *)object
{
    assert(object);
    assert(object.document);
    
    if (object.prototypeID) return nil;
    
    return [[self managedObjectClass] modelForDocument:[self.db.database documentWithID:object.document.documentID]];
}

- (void)refreshCachedValues {}

#pragma mark - Conflict resolution

- (BOOL)resolveConflictingRevisions:(NSError **)err
{
    for (MPManagedObject *mo in  [self allObjects])
        if (![self resolveConflictingRevisionsForObject:mo error:err])
            return NO;
    
    return YES;
}

// Overloadable in MPManagedObjectsController subclasses
- (BOOL)resolveConflictingRevisionsForObject:(MPManagedObject *)obj error:(NSError **)err
{
    assert(obj != nil);
    assert([obj isKindOfClass:[self managedObjectClass]]);
    
    NSArray *revs = nil;
    if (!(revs = [obj.document getConflictingRevisions:err]))
        return NO;
    
    if (revs.count < 2)
        return YES;
    
    revs = [revs sortedArrayUsingComparator:
            ^NSComparisonResult(CBLSavedRevision *revA, CBLSavedRevision *revB)
    {
        NSNumber *changedAtA = (revA.properties)[@"updatedAt"];
        NSNumber *changedAtB = (revB.properties)[@"updatedAt"];
        
        if (changedAtA)
            assert([changedAtA isKindOfClass:[NSNumber class]]);
        
        if (changedAtB)
            assert([changedAtB isKindOfClass:[NSNumber class]]);
        
        NSComparisonResult comparison = [changedAtA compare:changedAtB];
        
        if (comparison != NSOrderedSame) return comparison;
        
        // break ties using the revision ID
        return CBLCompareRevIDs(revA.revisionID, revB.revisionID);
    }];
    
    // delete all revisions but revs[0]
    for (NSUInteger i = 1; i < revs.count; i++)
    {
        CBLSavedRevision *rev = revs[i];
        if (![rev deleteDocument:err])
            return NO;
    }
    
    // create new revision with properties of rev[0]
    CBLSavedRevision *rev = revs[0];
    return [rev createRevisionWithProperties:rev.properties error:err];
}

#pragma mark -
#pragma mark Managed object CRUD

- (void)configureViews
{
    [[self.db.database viewNamed:@"objectsByPrototypeID"]
     setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit)
     {
         
         if (doc[@"prototypeID"])
             emit(doc[@"prototypeID"], nil);
         else
             emit([NSNull null], nil);
         
     } version:@"1.0"];
    
    __weak id weakSelf = self;
    [self.db.database setFilterNamed:@"managed-objects-filter"
                             asBlock:
     ^BOOL(CBLSavedRevision *revision, NSDictionary *params)
    {
        id strongSelf = weakSelf;
        return [strongSelf managesDocumentWithDictionary:revision.properties];
    }];
}

- (NSString *)allObjectsViewName
{
    return [NSString stringWithFormat:@"%@s", [[self class] managedObjectClassName]];
}

- (CBLQuery *)allObjectsQuery
{
    CBLQuery *query = [[self.db.database viewNamed:self.allObjectsViewName] createQuery];
    query.prefetch = YES;
    return query;
}

- (CBLQuery *)objectsByPrototypeQuery
{
    CBLQuery *query = [[self.db.database viewNamed:@"objectsByPrototypeID"] createQuery];
    query.prefetch = YES;
    return query;
}

- (NSArray *)objectsWithPrototypeID:(NSString *)prototypeID
{
    NSError *err = nil;
    NSArray *objs = [self managedObjectsForQueryEnumerator:[[self objectsByPrototypeQuery] run:&err]];
    if (!objs)
    {
        [[self.packageController notificationCenter] postErrorNotification:err];
        return nil;
    }
    return objs;
}

- (NSArray *)allObjects
{
    NSError *err = nil;
    
    CBLQuery *q = [self allObjectsQuery];
    NSArray *objs = [self managedObjectsForQueryEnumerator:[q run:&err]];
    if (!objs)
    {
        [[self.packageController notificationCenter] postErrorNotification:err];
        return nil;
    }

    return objs;
}

- (id)objectWithIdentifier:(NSString *)identifier
{
    assert(identifier);
    Class cls = [MPManagedObject managedObjectClassFromDocumentID:identifier];
    assert(cls);
    CBLDocument *doc = [self.db.database existingDocumentWithID:identifier];
    if (!doc) return nil;
    
    return [cls modelForDocument:doc];
}

- (id)newObject
{
    MPManagedObject *obj = [[[[self class] managedObjectClass] alloc] initWithNewDocumentForController:self];
    obj.objectType = [[self class] managedObjectClassName];
    obj.autosaves = [self autosavesObjects];
    return obj;
}

- (id)newObjectWithPrototype:(MPManagedObject *)prototype
{
    assert(prototype);
    assert([prototype isKindOfClass:[self managedObjectClass]]);
    assert([prototype canFormPrototype]);
    assert(prototype.document.documentID);
    
    MPManagedObject *obj = [[[prototype class] alloc] initWithNewDocumentForController:self];
    obj.prototypeID = prototype.document.documentID;
    
    for (NSString *key in prototype.document.userProperties)
    {
        [obj setValue:[prototype prototypeTransformedValueForPropertiesDictionaryKey:key forCopyManagedByController:self] ofProperty:key];
    }
    
    return obj;
}

- (BOOL)autosavesObjects
{
    return NO;
}

- (BOOL)observesManagedObjectChanges
{
    return YES;
}

- (NSArray *)objectsFromContentsOfArrayJSONAtURL:(NSURL *)url error:(NSError **)err
{
    NSData *objData = [NSData dataWithContentsOfURL:url options:NSDataReadingMapped error:err];
    if (!objData) return nil;
    
    JSONDecoder *decoder = [JSONDecoder decoderWithParseOptions:JKParseOptionNone];
    NSArray *objs = [decoder mutableObjectWithData:objData error:err];
    if (!objs) return nil;
    
    NSMutableArray *mos = [NSMutableArray arrayWithCapacity:objs.count];
    for (NSMutableDictionary *d in objs)
    {
        if (![d isManagedObjectDictionary:err]) {
            NSLog(@"ERROR: %@", *err);
            return nil;
        }
        NSString *docID = [d managedObjectDocumentID];
        assert(docID);
        
        Class moClass = NSClassFromString([d managedObjectType]);
        assert(moClass);
        
        CBLDocument *doc = [self.db.database existingDocumentWithID:docID];
        MPManagedObject *mo = doc ? [moClass modelForDocument:doc] : nil;
        
        if (mo)
        {
            [mo setValuesForPropertiesWithDictionary:d];
            if ([mo needsSave])
            {
                [mos addObject:mo];
            }
        }
        else
        {
            Class moc = NSClassFromString([d managedObjectType]);
            assert(moc);
            mo = [[moc alloc] initWithNewDocumentForController:self properties:d documentID:docID];
            [mos addObject:mo];
        }
        assert(mo);
    }
    
    if (mos.count > 0) {
        NSError *e = nil;
        if (![MPManagedObject saveModels:mos error:&e]) {
            if (err)
                *err = e;
            
            return nil;
        }
    }
    
    return mos;
}

#pragma mark - Querying

- (NSDictionary *)managedObjectByKeyMapForQueryEnumerator:(CBLQueryEnumerator *)rows
{
    NSMutableDictionary *entries = [NSMutableDictionary dictionaryWithCapacity:rows.count];
    for (CBLQueryRow *row in rows)
    {
        dispatch_sync(_queryQueue, ^{
            MPManagedObject *modelObj = (id)[row.document modelObject];
            
            if (!modelObj)
            {
                modelObj = _objectCache[row.document.documentID];
                modelObj.document = row.document;
                
                if (!modelObj)
                {
                    modelObj = [[row.document managedObjectClass] modelForDocument:row.document];
                }
            }
            else
            {
                modelObj.document = row.document;
            }
            
            assert([modelObj isKindOfClass:[MPManagedObject class]]);
            
            entries[row.key] = modelObj;
        });
    }
    
    return [entries copy];
}

- (NSArray *)managedObjectsForQueryEnumerator:(CBLQueryEnumerator *)rows
{
    NSMutableArray* entries = [NSMutableArray arrayWithCapacity:rows.count];
    for (CBLQueryRow* row in rows)
    {
        dispatch_sync(_queryQueue, ^{
            MPManagedObject *modelObj = (MPManagedObject *)[row.document modelObject];
            
            if (!modelObj)
            {
                modelObj = _objectCache[row.document.documentID];
                modelObj.document = row.document;
                
                if (!modelObj)
                {
                    modelObj = [[row.document managedObjectClass] modelForDocument:row.document];
                }
            }
            else
            {
                assert(modelObj.document == row.document);
            }
            
            assert([modelObj isKindOfClass:[MPManagedObject class]]);
            
            [entries addObject:modelObj];
        });
    }
    
    return [entries copy];
}


#pragma mark - Notification observing

- (void)hasAddedManagedObject:(NSNotification *)notification
{
    [self clearCachedValues];
}

- (void)hasUpdatedManagedObject:(NSNotification *)notification
{
    
}

- (void)hasRemovedManagedObject:(NSNotification *)notification
{
    [self clearCachedValues];
}

- (NSString *)bundledResourceDatabaseName
{
    return nil; // overload in subclass to load bundled data
}

- (void)loadBundledResourcesWithCompletionHandler:(void(^)(NSError *err))completionHandler
{
    NSString *resourceDBName = self.bundledResourceDatabaseName;
    
    // nothing to do if there is no resource for this controller
    if (!resourceDBName)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil);
        });
        return;
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *bundledBundlesPath
        = [[NSBundle mainBundle] pathForResource:resourceDBName ofType:@"cblite"];
    
    NSString *md5 = [fm md5DigestStringAtPath:bundledBundlesPath];
    MPMetadata *metadata = [self.db metadata];
    
    NSString *checksumKey = [NSString stringWithFormat:@"bundled-%@-md5", resourceDBName];
    
    // this version already loaded
    if ([[metadata getValueOfProperty:checksumKey] isEqualToString:md5])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(nil);
        });
        return;
    }
    
    CBLReplication *replication = nil;
    
    NSError *err = nil;
    if (![self.db pullFromDatabaseAtPath:bundledBundlesPath
                             replication:&replication error:&err])
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(err);
        });
        return;
    }
    
    __weak NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    __weak MPManagedObjectsController *weakSelf = self;
    __block id observer =
        [nc addObserverForName:kCBLReplicationChangeNotification
                        object:replication queue:[NSOperationQueue mainQueue]
                    usingBlock:
         ^(NSNotification *note) {
             MPManagedObjectsController *strongSelf = weakSelf;
             CBLReplication *r = note.object;
             assert(replication == r);
             if (r.status == kCBLReplicationStopped && !r.lastError)
             {
                 [metadata setValue:md5 ofProperty:checksumKey];
                 
                 NSError *metadataSaveErr = nil;
                 if (![metadata save:&metadataSaveErr])
                 {
                     NSLog(@"ERROR! Could not load bundled data from '%@.touchdb': %@", resourceDBName, metadataSaveErr);

                     [[strongSelf.packageController notificationCenter]
                        postErrorNotification:metadataSaveErr];
                 }
                 else
                 {
                     NSLog(@"Loaded bundled resource %@", resourceDBName);
                     
                     NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
                     [nc postNotificationName:MPManagedObjectsControllerLoadedBundledResourcesNotification object:self];
                 }
                 
                 [nc removeObserver:observer];
             }
             else if (r.status == kCBLReplicationStopped)
             {
                 NSLog(@"ERROR! Failed to pull from bundled database.");
                 [[self.packageController notificationCenter] postErrorNotification:r.lastError];
                 
                 [nc removeObserver:observer];
             }
             
         }];
}

#pragma mark - Loading bundled objects

- (NSArray *)loadBundledObjectsFromResource:(NSString *)resourceName
                              withExtension:(NSString *)extension
                           matchedToObjects:(NSArray *)preloadedObjects
                    dataChecksumMetadataKey:(NSString *)dataChecksumKey
                                      error:(NSError **)err
{
    NSArray *returnedObjects = nil;
    MPMetadata *metadata = [self.db metadata];
    
    NSURL *jsonURL = [[NSBundle mainBundle] URLForResource:resourceName withExtension:extension];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *md5 = [fm md5DigestStringAtPath:[jsonURL path]];
    
    if ([md5 isEqualToString:[metadata getValueOfProperty:dataChecksumKey]])
    {
        returnedObjects = preloadedObjects;
        assert(returnedObjects);
    }
    else
    {
        returnedObjects = [self objectsFromContentsOfArrayJSONAtURL:jsonURL error:err];
        
        assert(returnedObjects);
        if (!returnedObjects && err && *err)
        {
            NSLog(@"ERROR! Could not load bundled data from resource %@%@:\n%@", resourceName, extension, *err);
            [[NSNotificationCenter defaultCenter] postErrorNotification:*err];
        }
        else
        {
            [metadata setValue:md5 ofProperty:dataChecksumKey];
            if (![metadata save:err])
                return NO;
        }
    }
    
    assert(returnedObjects);
    return returnedObjects;
}

@end

@implementation MPManagedObjectsController (Protected)

- (dispatch_queue_t)queryQueue { return _queryQueue; }

- (void)willSaveObject:(MPManagedObject *)object
{
    assert(object.controller == self);
    assert(self.db);
    MPLog(@"Will save object %@", object);
}

- (void)didSaveObject:(MPManagedObject *)object
{
    assert(object.controller == self);
    assert(self.db);
    MPLog(@"Did save object %@:\n%@ in %@", object, [[object document] properties], self.db.database.internalURL);
    
    NSNotificationCenter *nc = [_packageController notificationCenter]; assert(nc);
    
    /*
    NSString *recentChange = [NSNotificationCenter notificationNameForRecentChangeOfType:MPChangeTypeAdd
                                                                   forManagedObjectClass:[object class]];
    
    NSString *pastChange = [NSNotificationCenter notificationNameForPastChangeOfType:MPChangeTypeAdd
                                                               forManagedObjectClass:[object class]];
    
    [nc postNotificationName:recentChange object:object];
    
    [nc postNotificationName:pastChange object:object];
     */

    if ([[self.packageController delegate] respondsToSelector:@selector(updateChangeCount:)])
        [[self.packageController delegate] updateChangeCount:NSChangeDone];
}

- (void)didUpdateObject:(MPManagedObject *)object
{
    assert(object.controller == self);
    assert([object isKindOfClass:[self managedObjectClass]]);
    assert(self.db);
    MPLog(@"Did change object %@", object);
    NSNotificationCenter *nc = [_packageController notificationCenter]; assert(nc);
    
    /*
    NSString *recentChange = [NSNotificationCenter notificationNameForRecentChangeOfType:MPChangeTypeUpdate forManagedObjectClass:[object class]];
    NSString *pastChange = [NSNotificationCenter notificationNameForPastChangeOfType:MPChangeTypeUpdate forManagedObjectClass:[object class]];
    
    [nc postNotificationName:recentChange object:object];
    
    [nc postNotificationName:pastChange object:object];
    */
    
    if ([[self.packageController delegate] respondsToSelector:@selector(updateChangeCount:)])
        [[self.packageController delegate] updateChangeCount:NSChangeDone];
}

- (void)willDeleteObject:(MPManagedObject *)object
{
    assert(object.controller == self);
    assert([object isKindOfClass:[self managedObjectClass]]);
    assert(self.db);
    MPLog(@"Will delete object %@", object);
    [self deregisterObject:object];
}

- (void)didDeleteObject:(MPManagedObject *)object
{
    assert(object.controller == self);
    assert([object isKindOfClass:[self managedObjectClass]]);
    assert(self.db);
    MPLog(@"Did delete object %@", object);
    NSNotificationCenter *nc = [_packageController notificationCenter]; assert(nc);
    
    [nc postNotificationName:[NSNotificationCenter notificationNameForRecentChangeOfType:MPChangeTypeRemove
                                                                     forManagedObjectClass:[object class]] object:object];
    
    [nc postNotificationName:[NSNotificationCenter notificationNameForPastChangeOfType:MPChangeTypeRemove
                                                             forManagedObjectClass:[object class]] object:object];
    
    if ([[self.packageController delegate] respondsToSelector:@selector(updateChangeCount:)])
        [[self.packageController delegate] updateChangeCount:NSChangeDone];
}

- (void)didChangeDocument:(CBLDocument *)doc
                forObject:(MPManagedObject *)object
                   source:(MPManagedObjectChangeSource)source
{
    NSNotificationCenter *nc = [_packageController notificationCenter]; assert(nc);
    
    // TODO: get rid of this hack and reason properly about whether an object is new or updated.
    BOOL documentIsNew = [doc.currentRevision.revisionID isMatchedByRegex:@"^1-"];
    BOOL documentIsDeleted = doc.currentRevision.isDeletion;
    
    NSDictionary *changeDict = @{ @"source":@(source) };
    
    // document new => add change type.
    // document is not new &  document is deleted => remove change type
    // document is now new & document is NOT deleted => update change type
    MPChangeType changeType = documentIsNew ? MPChangeTypeAdd : (documentIsDeleted ? MPChangeTypeRemove : MPChangeTypeUpdate);
    
    [nc postNotificationName:[NSNotificationCenter notificationNameForRecentChangeOfType:changeType
                                                                   forManagedObjectClass:[object class]] object:object userInfo:changeDict];
    
    [nc postNotificationName:[NSNotificationCenter notificationNameForPastChangeOfType:changeType
                                                                 forManagedObjectClass:[object class]] object:object userInfo:changeDict];
}

- (void)didLoadObjectFromDocument:(MPManagedObject *)object
{
    assert(object.controller == self);
    assert([object isKindOfClass:[self managedObjectClass]]);
    assert(self.db);
    //DDLogVerbose(@"Did load object %@", object);
    NSNotificationCenter *nc = [_packageController notificationCenter]; assert(nc);
    
    [object setController:self];
    [self registerObject:object];
}

- (void)registerObject:(MPManagedObject *)mo
{
    assert([mo isKindOfClass:[self managedObjectClass]]);
    assert(_objectCache);
    assert(mo.document.documentID);
    _objectCache[mo.document.documentID] = mo;
}

- (void)deregisterObject:(MPManagedObject *)mo
{
    assert([mo isKindOfClass:[self managedObjectClass]]);
    assert(mo.document.documentID);
    assert(_objectCache);
    [_objectCache removeObjectForKey:mo.document.documentID];
}

@end


@implementation CBLDocument (MPManagedObjectExtensions)

- (Class)managedObjectClass
{
    NSString *objectType = self.properties[@"objectType"];
    assert(objectType);
    
    return NSClassFromString(objectType);
}

@end