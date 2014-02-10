//
//  MPManagedObjectsController.m
//  Feather
//
//  Created by Matias Piipari on 16/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Feather/MPManagedObject+Protected.h>
#import <Feather/NSBundle+MPExtensions.h>

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
#import <TouchDB/TouchDB.h>
#import <CouchCocoa/CouchCocoa.h>
#import <CouchCocoa/CouchDesignDocument_Embedded.h>

#import "Mixin.h"
#import "MPCacheableMixin.h"

#import <objc/runtime.h>
#import <objc/message.h>

NSString * const MPManagedObjectsControllerErrorDomain = @"MPManagedObjectsControllerErrorDomain";

NSString * const MPManagedObjectsControllerLoadedBundledResourcesNotification = @"MPManagedObjectsControllerLoadedBundledResourcesNotification";

@interface MPManagedObjectsController ()
{
    NSSet *_managedObjectSubclasses;
    dispatch_queue_t _queryQueue;
}

@property (readonly, strong) NSMutableDictionary *objectCache;

@property (readonly, strong) dispatch_queue_t designDocumentQueue;

@property (readonly, strong) CouchQuery *objectsByPrototypeQuery;

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

- (instancetype)initWithPackageController:(MPDatabasePackageController *)packageController database:(MPDatabase *)db
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
        
        _designDocumentQueue = dispatch_queue_create(
                    [[NSString stringWithFormat:@"com.piipari.controller[%@]",
                      [[self class] managedObjectClassName]] UTF8String], DISPATCH_QUEUE_SERIAL);
        
        [packageController registerManagedObjectsController:self];
        
        _designDocument = [self.db.database designDocumentWithName:NSStringFromClass([self class])];
        [self configureDesignDocument:_designDocument];
        
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
        
        [self loadBundledResources];
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

- (BOOL)managesDocumentWithDictionary:(NSDictionary *)couchDocumentDict
{
    NSString *objectType = [couchDocumentDict managedObjectType];
    
    if (!objectType) return NO;
    return [self.managedObjectSubclasses containsObject:objectType];
}

- (BOOL)managesObjectsOfClass:(Class)class
{
    return [self.managedObjectSubclasses containsObject:NSStringFromClass(class)];
}

- (TDMapBlock)allObjectsBlock
{
    return ^(NSDictionary *doc, TDMapEmitBlock emit)
    {
        if (![self managesDocumentWithDictionary:doc]) return;
        emit(doc[@"_id"], nil);
    };
}

- (TDMapBlock)bundledObjectsBlock
{
    return ^(NSDictionary *doc, TDMapEmitBlock emit)
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

- (void)resolveConflictingRevisions
{
    for (MPManagedObject *mo in  [self allObjects])
        [self resolveConflictingRevisionsForObject:mo];
}

// Overloadable in MPManagedObjectsController subclasses
- (void)resolveConflictingRevisionsForObject:(MPManagedObject *)obj
{
    assert(obj != nil);
    assert([obj isKindOfClass:[self managedObjectClass]]);
    
    NSArray *revs = [obj.document getConflictingRevisions];
    if (revs.count < 2) return;
    
    revs = [revs sortedArrayUsingComparator:^NSComparisonResult(CouchRevision *revA, CouchRevision *revB) {
        NSNumber *changedAtA = [revA.properties objectForKey:@"updatedAt"];
        NSNumber *changedAtB = [revB.properties objectForKey:@"updatedAt"];
        
        if (changedAtA)
            assert([changedAtA isKindOfClass:[NSNumber class]]);
        
        if (changedAtB)
            assert([changedAtB isKindOfClass:[NSNumber class]]);
        
        NSComparisonResult comparison = [changedAtA compare:changedAtB];
        
        if (comparison != NSOrderedSame) return comparison;
        
        // break ties using the revision ID
        return TDCompareRevIDs(revA.revisionID, revB.revisionID);
    }];
    
    [obj.document resolveConflictingRevisions:revs withRevision:revs[0]];
}

#pragma mark -
#pragma mark Managed object CRUD

- (void)configureDesignDocument:(CouchDesignDocument *)designDoc
{
    assert(designDoc == _designDocument);
    
    [designDoc defineViewNamed:@"objectsByPrototypeID"
                      mapBlock:^(NSDictionary *doc, TDMapEmitBlock emit)
    {
    
        if ([doc objectForKey:@"prototypeID"])
            emit([doc objectForKey:@"prototypeID"], nil);
        else
            emit([NSNull null], nil);
    
    } version:@"1.0"];
    
    [designDoc defineFilterNamed:@"managed-objects-filter"
                                        block:
     ^BOOL(TD_Revision *revision, NSDictionary *params) {
         return [self managesDocumentWithDictionary:revision.properties];
     }];
}

- (NSString *)allObjectsViewName
{
    return [NSString stringWithFormat:@"%@s", [[self class] managedObjectClassName]];
}

- (CouchQuery *)allObjectsQuery
{
    CouchQuery *query = [self.designDocument queryViewNamed:[self allObjectsViewName]];
    query.prefetch = YES;
    return query;
}

- (CouchQuery *)objectsByPrototypeQuery
{
    CouchQuery *query = [self.designDocument queryViewNamed:@"objectsByPrototypeID"];
    query.prefetch = YES;
    return query;
}

- (NSArray *)objectsWithPrototypeID:(NSString *)prototypeID
{
    return [self managedObjectsForQueryEnumerator:[[self objectsByPrototypeQuery] rows]];
}

- (NSArray *)allObjects
{
    return [self managedObjectsForQueryEnumerator:[[self allObjectsQuery] rows]];
}

- (id)objectWithIdentifier:(NSString *)identifier
{
    assert(identifier);
    Class cls = [MPManagedObject managedObjectClassFromDocumentID:identifier];
    assert(cls);
    CouchDocument *doc = [self.db.database getDocumentWithID:identifier];
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
        
        CouchDocument *doc = [self.db.database getDocumentWithID:docID];
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
    
    if (mos.count > 0)
    {
        RESTOperation *saveOperation = [MPManagedObject saveModels:mos];
        [saveOperation wait];
        if ([saveOperation error])
        {
            if (err) *err = saveOperation.error; return nil;
        }        
    }
    
    return mos;
}

#pragma mark - Querying

- (NSDictionary *)managedObjectByKeyMapForQueryEnumerator:(CouchQueryEnumerator*)rows
{
    NSMutableDictionary *entries = [NSMutableDictionary dictionaryWithCapacity:rows.count];
    for (CouchQueryRow* row in rows)
    {
        dispatch_sync(_queryQueue, ^{
            MPManagedObject *modelObj = [row.document modelObject];
            
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

- (NSArray *)managedObjectsForQueryEnumerator:(CouchQueryEnumerator*)rows
{
    NSMutableArray* entries = [NSMutableArray arrayWithCapacity:rows.count];
    for (CouchQueryRow* row in rows)
    {
        dispatch_sync(_queryQueue, ^{
            MPManagedObject *modelObj = [row.document modelObject];
            
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

- (BOOL)loadsBundledResourcesSynchronously
{
    return [NSBundle inTestSuite];
}

- (void)loadBundledResources
{
    NSString *resourceDBName = self.bundledResourceDatabaseName;
    if (!resourceDBName)
        return;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *bundledBundlesPath = [[NSBundle mainBundle] pathForResource:resourceDBName ofType:@"touchdb"];
    NSString *md5 = [fm md5DigestStringAtPath:bundledBundlesPath];
    MPMetadata *metadata = [self.db metadata];
    
    NSString *checksumKey = [NSString stringWithFormat:@"bundled-%@-md5", resourceDBName];
    
    
    if ([[metadata getValueOfProperty:checksumKey] isEqualToString:md5])
        return;
    
    // kept as nil if loading is intended to be asynchronous.
    dispatch_semaphore_t blocker = self.loadsBundledResourcesSynchronously ? nil : dispatch_semaphore_create(0);
    
    [self.db pullFromDatabaseAtPath:bundledBundlesPath
              withCompletionHandler:
     ^(NSError *err) {
         if (err)
         {
             NSLog(@"ERROR! Could not load bundled data from '%@.touchdb': %@", resourceDBName, err);
         }
         else
         {
             NSLog(@"Loaded bundled bundles.");
             [metadata setValue:md5 ofProperty:@"bundled-bundles-md5"];
             [metadata save];
         }
         
         if (blocker)
             dispatch_semaphore_signal(blocker);
     }];

    if (blocker)
        dispatch_semaphore_wait(blocker, DISPATCH_TIME_FOREVER);

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:MPManagedObjectsControllerLoadedBundledResourcesNotification object:self];
}

#pragma mark - Loading bundled objects

- (NSArray *)loadBundledObjectsFromResource:(NSString *)resourceName
                          withExtension:(NSString *)extension
                       matchedToObjects:(NSArray *)preloadedObjects
                dataChecksumMetadataKey:(NSString *)dataChecksumKey
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
        NSError *err = nil;
        returnedObjects = [self objectsFromContentsOfArrayJSONAtURL:jsonURL error:&err];
        assert(returnedObjects);
        if (err || !returnedObjects)
        {
            NSLog(@"ERROR! Could not load bundled data from resource %@%@:\n%@", resourceName, extension, err);
            [[NSNotificationCenter defaultCenter] postErrorNotification:err];
        }
        else
        {
            [metadata setValue:md5 ofProperty:dataChecksumKey];
            [metadata save];
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
    MPLog(@"Did save object %@:\n%@ in %@", object, [[object document] properties], self.db.database.URL);
    
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

- (void)didChangeDocument:(CouchDocument *)doc forObject:(MPManagedObject *)object source:(MPManagedObjectChangeSource)source
{
    NSNotificationCenter *nc = [_packageController notificationCenter]; assert(nc);
    
    // TODO: get rid of this hack and reason properly about whether an object is new or updated.
    BOOL documentIsNew = [[[doc currentRevision] revisionID] isMatchedByRegex:@"^1-"];
    BOOL documentIsDeleted = [[doc currentRevision] isDeleted];
    
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


@implementation CouchDocument (MPManagedObjectExtensions)

- (Class)managedObjectClass
{
    NSString *objectType = self.properties[@"objectType"];
    assert(objectType);
    
    return NSClassFromString(objectType);
}

@end