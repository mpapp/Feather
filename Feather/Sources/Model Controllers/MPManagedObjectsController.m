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

#import "MPDatabasePackageController.h"
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

#import "MPShoeboxPackageController.h"

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

@interface MPManagedObjectsController ()  <CBLReplicationDelegate>
{
    NSSet *_managedObjectSubclasses;
}
@property (readonly, strong) NSMutableDictionary *objectCache;

@property (readonly) BOOL loadingBundledDatabaseResources;

@property (readonly) BOOL loadingBundledJSONResources;

@property (readwrite) NSArray *bundledJSONDerivedData;

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
                                    error:(NSError **)err {
    // MPManagedObjectsController is abstract
    assert([self class] != [MPManagedObjectsController class]);

    if (self = [super init])
    {
        assert(db);

        _packageController = packageController;
        _db = db;

        _objectCache = [NSMutableDictionary dictionaryWithCapacity:1000];

        [packageController registerManagedObjectsController:self];

        mp_dispatch_sync(db.server.dispatchQueue, [self.packageController serverQueueToken], ^{
            [self configureViews];
        });

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
        
        [self implementDefaultScriptObjectAccessor];
    }

    return self;
}

- (void)implementDefaultScriptObjectAccessor {
    // implement default scripting object property
    // matches the property key returned by -objectSpecifierKey of self.managedObjectClass
    NSString *allObjectsSpecifierKey = [self.managedObjectClass objectSpecifierKey];
    SEL allObjectsForObjectSpecifierKeySel = NSSelectorFromString(allObjectsSpecifierKey);

    if (![self respondsToSelector:allObjectsForObjectSpecifierKeySel]) {
        id (^allObjectsForObjectSpecifierKey)() = ^id() {
            return [self allObjects];
        };
        
        NSLog(@"Implementing '%@'", allObjectsSpecifierKey);
        
        BOOL success = class_addMethod(self.class,
                                       allObjectsForObjectSpecifierKeySel,
                                       imp_implementationWithBlock(allObjectsForObjectSpecifierKey), "@@:");
        
        // add a property declaration as well.
        objc_property_attribute_t type = { "T", "@\"NSArray\"" };
        objc_property_attribute_t ownership = { "C", "" }; // C = copy
        objc_property_attribute_t attribs[] = {type, ownership};
        
        class_addProperty(self.class, [allObjectsSpecifierKey UTF8String], attribs, 2);
        assert(success);
        assert([self respondsToSelector:allObjectsForObjectSpecifierKeySel]);

#ifdef DEBUG_TEST_DEFAULT_SCRIPT_OBJECT_ACCESS
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id o = [self performSelector:allObjectsForObjectSpecifierKeySel withObject:nil];
#pragma clang diagnostic pop
        NSLog(@"%@", o);
#endif
    }
}

- (BOOL)didInitialize:(NSError **)error
{
    if ([NSBundle isCommandLineTool] || [NSBundle isXPCService])
        return YES; // Only the main application can set up the shared databases under the group container
    
    if (![self loadBundledDatabaseResources:error])
        return NO;
    
    if (![self loadBundledJSONResources:error])
        return NO;
    
    return YES;
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
        NSArray *subclasses = MPManagedObject.subclasses;
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
        NSMutableArray *subclasses = [cls.subclasses mutableCopy];

        NSLog(@"Subclasses of %@: %@", NSStringFromClass(cls), subclasses);

        [subclassSet addObject:cls];
        [subclassSet addObjectsFromArray:subclasses];

        while (subclasses.count > 0)
        {
            Class subcls = [subclasses firstObject];
            [subclassSet addObjectsFromArray:subcls.subclasses];
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
        emit(doc[@"_id"], doc);
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

- (void)viewNamed:(NSString *)name setMapBlock:(CBLMapBlock)block version:(NSString *)version
{
    [self.packageController registerViewName:name];
    [[self.db.database viewNamed:name] setMapBlock:block version:version];
}

- (void)viewNamed:(NSString *)name setMapBlock:(CBLMapBlock)block setReduceBlock:(CBLReduceBlock)reduceBlock version:(NSString *)version
{
    [self.packageController registerViewName:name];
    [[self.db.database viewNamed:name] setMapBlock:block reduceBlock:reduceBlock version:version];
}

- (void)configureViews
{
    [[self.db.database viewNamed:@"objectsByPrototypeID"]
     setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit)
     {
         if (doc[@"prototype"])
             emit(doc[@"prototype"], nil);
         else
             emit([NSNull null], nil);

     } version:@"1.0"];
    
    [[self.db.database viewNamed:self.objectsByTitleViewName]
     setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit)
    {
        if (![self managesDocumentWithDictionary:doc])
            return;
        
        if (!doc[@"title"])
            return;
        
        emit(doc[@"title"], nil);
    } version:@"1.0"];
    
    __weak id weakSelf = self;
    [self.db.database setFilterNamed:MPStringF(@"%@/managed-objects-filter", NSStringFromClass(self.class))
                             asBlock:
     ^BOOL(CBLSavedRevision *revision, NSDictionary *params)
    {
        id strongSelf = weakSelf;
        BOOL manages = [strongSelf managesDocumentWithDictionary:revision.properties];
        if (!manages)
            return NO;
        
        return YES;
    }];
    
    [[self.db.database viewNamed:self.bundledJSONDataViewName]
                    setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit)
     {
         if (![self managesDocumentWithDictionary:doc])
             return;
         
         if (![doc[@"bundled"] boolValue])
             return;
         
         emit(doc.managedObjectDocumentID, nil);
     } version:@"1.1"];
}

- (NSString *)allObjectsViewName
{
    return [NSString stringWithFormat:@"all-%@s", [[self class] managedObjectClassName]];
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
    return [self objectsMatchingQueriedView:@"objectsByPrototypeID" keys:@[prototypeID]];
}

- (NSString *)objectsByTitleViewName
{
    return [NSString stringWithFormat:@"%@-by-title", self.managedObjectClassName];
}

- (NSArray *)objectsWithTitle:(NSString *)title
{
    NSParameterAssert(title);
    CBLQuery *q = [[self.db.database viewNamed:self.objectsByTitleViewName] createQuery];
    q.keys = @[title];
    
    return [self managedObjectsForQueryEnumerator:q.run];
}

- (NSArray *)allObjects
{
    CBLQuery *q = [self allObjectsQuery];
    
    __block NSArray *objs;
    objs = [self managedObjectsForQueryEnumerator:[q run]];
    
    return objs;
}

- (id)valueWithUniqueID:(id)uniqueID inPropertyWithKey:(NSString *)key {
    assert([key hasPrefix:@"all"]); // assuming there are unique objects only for one kind of element.
    return [self objectWithIdentifier:uniqueID];
}

- (id)objectWithIdentifier:(NSString *)identifier
{
    MPManagedObject *mo = _objectCache[identifier];
    if (mo)
    {
        assert(mo.controller == self);
        return mo;
    }
    
    assert(identifier);
    Class cls = [MPManagedObject managedObjectClassFromDocumentID:identifier];
    assert(cls);
    __block CBLDocument *doc = nil;
    
    mp_dispatch_sync(self.db.database.manager.dispatchQueue, [self.packageController serverQueueToken], ^{
        doc = [self.db.database existingDocumentWithID:identifier];
    });
    
    if (!doc) {
        if (!self.relaysFetchingByIdentifier && self.packageController != [MPShoeboxPackageController sharedShoeboxController]) {
            MPLog(@"WARNING! Failed to find object by ID: %@", identifier);
            return nil;
        }
        
        MPManagedObjectsController *moc
            = [[MPShoeboxPackageController sharedShoeboxController] controllerForManagedObjectClass:cls];
        return [moc objectWithIdentifier:identifier];
    }
    
    return [cls modelForDocument:doc];
}

- (BOOL)relaysFetchingByIdentifier {
    return NO;
}

- (id)newObject
{
    MPManagedObject *obj = [[[[self class] managedObjectClass] alloc] initWithNewDocumentForController:self];
    obj.objectType = [[self class] managedObjectClassName];
    obj.autosaves = [self autosavesObjects];
    return obj;
}

- (Class)prototypeClass {
    return self.managedObjectClass;
}

- (id)newObjectWithPrototype:(MPManagedObject *)prototype
{
    assert(prototype);
    assert([prototype isKindOfClass:self.prototypeClass]);
    assert([prototype canFormPrototype]);
    assert(prototype.document.documentID);

    // TODO: might need also -prototypeInstanceClassForPrototype: if this appers insufficient.
    Class instantiableClass = self.prototypeClass == self.managedObjectClass
                                ? prototype.class
                                : self.managedObjectClass;
    
    MPManagedObject *obj = [[instantiableClass alloc] initWithNewDocumentForController:self];
    obj.prototype = prototype;

    for (NSString *key in prototype.document.userProperties)
    {
        id transformedValue = [prototype prototypeTransformedValueForPropertiesDictionaryKey:key
                                                                  forCopyManagedByController:self];
        [obj setValue:transformedValue ofProperty:key];
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
    if (!objData)
        return nil;

    return [self objectsFromArrayJSONData:objData error:err];
}

- (NSArray *)objectsFromArrayJSONData:(NSData *)objData error:(NSError *__autoreleasing *)err
{
    JSONDecoder *decoder = [JSONDecoder decoderWithParseOptions:JKParseOptionNone];
    NSArray *objs = [decoder mutableObjectWithData:objData error:err];
    if (!objs)
        return nil;
    
    return [self objectsFromJSONEncodableObjectArray:objs error:err];
}

- (NSArray *)objectsFromJSONEncodableObjectArray:(NSArray *)objs error:(NSError **)err
{
    NSMutableArray *mos = [NSMutableArray arrayWithCapacity:objs.count];
    for (NSMutableDictionary *d in objs)
    {
        BOOL isExisting = NO;
        MPManagedObject *mo = [self objectFromJSONDictionary:d isExisting:&isExisting error:err];
        
        if (!mo)
            return nil;
        
        if (mo.needsSave || !isExisting)
            [mos addObject:mo];
    }
    
    if (mos.count > 0) {
        NSError *e = nil;
        if (![MPManagedObject saveModels:mos error:&e]) {
            if (err)
                *err = e;
            
            return nil;
        }
    }
    
    return mos.copy;
}

- (MPManagedObject *)objectFromJSONDictionary:(NSDictionary *)d isExisting:(BOOL *)isExisting error:(NSError **)err
{
    if (![d isManagedObjectDictionary:err]) {
        NSLog(@"ERROR: %@", *err);
        assert(false);
        return nil;
    }
    
    NSString *docID = [d managedObjectDocumentID];
    assert(docID);
    
    Class moClass = NSClassFromString([d managedObjectType]);
    assert(moClass);
    
    __block CBLDocument *doc = nil;
    mp_dispatch_sync([(CBLManager *)[self.packageController server] dispatchQueue],
                     [self.packageController serverQueueToken], ^{
                         doc = [self.db.database existingDocumentWithID:docID];
                     });
    
    MPManagedObject *mo = doc ? [moClass modelForDocument:doc] : nil;
    
    if (mo)
    {
        [mo setValuesForPropertiesWithDictionary:d];
        if (mo.needsSave && isExisting)
            *isExisting = YES;
    }
    else
    {
        Class moc = NSClassFromString([d managedObjectType]);
        assert(moc);
        mo = [[moc alloc] initWithNewDocumentForController:self properties:d documentID:docID];
    }
    
    NSParameterAssert(mo);
    return mo;
}

#pragma mark - Querying

- (NSDictionary *)managedObjectByKeyMapForQueryEnumerator:(CBLQueryEnumerator *)rows
{
    NSMutableDictionary *entries = [NSMutableDictionary dictionaryWithCapacity:rows.count];
    for (CBLQueryRow *row in rows) {
        mp_dispatch_sync(self.db.database.manager.dispatchQueue, [self.packageController serverQueueToken], ^{
            MPManagedObject *modelObj = (id)[row.document modelObject];

            if (!modelObj) {
                modelObj = _objectCache[row.document.documentID];
                modelObj.document = row.document;

                if (!modelObj) {
                    modelObj = [[row.document managedObjectClass] modelForDocument:row.document];
                }
            }
            else
            {
                assert(modelObj.document);
                //modelObj.document = row.document;
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
        mp_dispatch_sync(self.db.database.manager.dispatchQueue, [self.packageController serverQueueToken], ^{
            MPManagedObject *modelObj = (MPManagedObject *)[row.document modelObject];

            if (!modelObj) {
                modelObj = _objectCache[row.document.documentID];
                modelObj.document = row.document;

                if (!modelObj) {
                    modelObj = [[row.document managedObjectClass] modelForDocument:row.document];
                }
            }
            else {
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
    return nil; // override in subclass to load bundled data
}

- (NSString *)bundledJSONDataViewName {
    return [NSString stringWithFormat:@"bundled-%@", [self.managedObjectClass plural]];
}

- (CBLQuery *)bundledJSONDataQuery {
    
    if (!self.bundledJSONDataFilename)
        return nil;
    
    NSParameterAssert(self.bundledJSONDataViewName);
    CBLQuery *q = [[self.db.database viewNamed:self.bundledJSONDataViewName] createQuery];
    q.prefetch = YES;
    
    return q;
}

- (NSString *)bundledJSONDataFilename {
    return nil; // override in subclass to bundle data.
}

- (BOOL)hasBundledJSONData {
    return self.bundledJSONDataFilename != nil;
}

- (NSString *)bundledJSONDataChecksumKey {
    return [NSString stringWithFormat:@"%@-checksum", self.bundledJSONDataFilename];
}

- (NSComparator)bundledJSONDataComparator {
    return nil;
}

- (BOOL)loadBundledJSONResources:(NSError **)err {
    
    if (!self.bundledJSONDataFilename)
        return YES;
    
    NSParameterAssert(!_loadingBundledJSONResources);
    _loadingBundledJSONResources = YES;
    
    NSParameterAssert(self.bundledJSONDataQuery);
    
    NSArray *foundBundledObjs =
        [self managedObjectsForQueryEnumerator:self.bundledJSONDataQuery.run];
    
    _bundledJSONDerivedData =
        [self loadBundledObjectsFromResource:self.bundledJSONDataFilename
                               withExtension:@".json"
                            matchedToObjects:foundBundledObjs
                     dataChecksumMetadataKey:self.bundledJSONDataChecksumKey error:err];
    
    if (!_bundledJSONDerivedData) {
        return NO;
    }

    else if (self.bundledJSONDataComparator)
        _bundledJSONDerivedData = [_bundledJSONDerivedData sortedArrayUsingComparator:self.bundledJSONDataComparator];
    
    NSParameterAssert(_bundledJSONDerivedData);
    return YES;
}

- (BOOL)loadBundledDatabaseResources:(NSError **)error
{
    assert(!_loadingBundledDatabaseResources);
    _loadingBundledDatabaseResources = YES;
    
    assert([NSThread isMainThread]);
    
    NSString *checksumKey = [NSString stringWithFormat:@"bundled-%@-checksum",
                             self.bundledResourceDatabaseName];

    // nothing to do if there is no resource for this controller
    if (!self.bundledResourceDatabaseName)
    {
        return YES;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *attachmentsDirectoryName = MPStringF(@"%@ attachments", self.bundledResourceDatabaseName);
    NSString *bundledBundlesPath = [[NSBundle appBundle] pathForResource:self.bundledResourceDatabaseName ofType:@"cblite"];
    NSString *bundledAttachmentsPath = [[NSBundle appBundle] pathForResource:attachmentsDirectoryName ofType:@""];
    
    NSError *err = nil;
    NSURL *tempBundledBundlesDirURL = [fm temporaryDirectoryURLInApplicationCachesSubdirectoryNamed:checksumKey error:&err];
    NSString *tempBundledBundlesPath = [tempBundledBundlesDirURL.path stringByAppendingPathComponent:[bundledBundlesPath lastPathComponent]];
    NSString *tempAttachmentsPath = [tempBundledBundlesDirURL.path stringByAppendingPathComponent:attachmentsDirectoryName];
    
    if (!tempBundledBundlesPath || !tempAttachmentsPath) {
        err = [NSError errorWithDomain:MPManagedObjectErrorDomain
                                  code:MPManagedObjectsControllerErrorCodeFailedTempFileCreation
                              userInfo:@{NSLocalizedDescriptionKey:MPStringF(@"Failed to derive temporary paths from %@ and %@", bundledBundlesPath, bundledAttachmentsPath)}];
        
        if (error)
            *error = err;
        
        return NO;
    }
    
    NSString *md5 = [fm md5DigestStringAtPath:bundledBundlesPath];
    // TODO: check md5 for attachments also
    
    MPMetadata *metadata = [self.db metadata];

    // this version already loaded
    if ([[metadata getValueOfProperty:checksumKey] isEqualToString:md5])
    {
        return YES;
    }
    
    if (![fm copyItemAtPath:bundledBundlesPath toPath:tempBundledBundlesPath error:error])
        return NO;
    
    if ([fm fileExistsAtPath:bundledAttachmentsPath])
        if (![fm copyItemAtPath:bundledAttachmentsPath toPath:tempAttachmentsPath error:error])
            return NO;
    
    //__block BOOL shouldRun = YES;
    
    CBLReplication *replication = nil;
    
    if (![self.db pullFromDatabaseAtPath:tempBundledBundlesPath
                             replication:&replication
                                   error:error]) { // if failed to START replication
        
        if (![NSFileManager.defaultManager removeItemAtPath:tempBundledBundlesDirURL.path error:&err])
            NSLog(@"ERROR! Failed to remove temporary data from path %@: %@",
                  tempBundledBundlesPath, err);
        
        return NO;
    }
    
    replication.delegate = self;
    
    __weak NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    __weak MPManagedObjectsController *weakSelf = self;
    __block id replicationObserver =
        [nc addObserverForName:kCBLReplicationChangeNotification
                        object:replication queue:[NSOperationQueue mainQueue]
                    usingBlock:
        ^(NSNotification *note)
    {
        MPManagedObjectsController *strongSelf = weakSelf;
        CBLReplication *r = note.object;
        NSParameterAssert(replication == r);
        
        [strongSelf processUpdatedBundledDataLoadReplication:replication];
    }];
    
    while (_loadingBundledDatabaseResources)
    {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:replicationObserver];

    [metadata setValue:md5 ofProperty:checksumKey];

    if (![NSFileManager.defaultManager removeItemAtPath:tempBundledBundlesDirURL.path error:&err])
        NSLog(@"ERROR! Failed to remove temporary data from path %@: %@", tempBundledBundlesPath, err);
    
    MPLog(@"Completed loading resources for %@", self);
    
    return YES;
}

- (BOOL)hasBundledResourceDatabase {
    return self.bundledResourceDatabaseName != nil;
}

- (BOOL)requiresBundledDataLoading {
    return self.hasBundledJSONData || self.hasBundledResourceDatabase;
}

- (void)processUpdatedBundledDataLoadReplication:(CBLReplication *)replication
{
    MPMetadata *metadata = self.db.metadata;
    //NSParameterAssert(!replication.lastError);
    if (replication.status == kCBLReplicationStopped && !replication.lastError)
    {
        __block BOOL metadataSaveSuccess = NO;
        __block NSError *metadataSaveErr = nil;
        mp_dispatch_sync(self.db.database.manager.dispatchQueue, [self.packageController serverQueueToken], ^{
            metadataSaveSuccess = [metadata save:&metadataSaveErr];
        });
        
        _loadingBundledDatabaseResources = NO;

        if (!metadataSaveSuccess)
        {
            NSLog(@"ERROR! Could not load bundled data from '%@.touchdb': %@", self.bundledResourceDatabaseName, metadataSaveErr);
            
            [[self.packageController notificationCenter] postErrorNotification:metadataSaveErr];
        }
        else
        {
            NSLog(@"Loaded bundled resource %@", self.bundledResourceDatabaseName);
            
            NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
            [nc postNotificationName:MPManagedObjectsControllerLoadedBundledResourcesNotification object:self];
        }
    }
    else if (replication.status == kCBLReplicationStopped)
    {
        NSLog(@"ERROR! Failed to pull from bundled database.");
        [[self.packageController notificationCenter] postErrorNotification:replication.lastError];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            _loadingBundledDatabaseResources = NO;
        });
    }
}

- (void)replicationDidProgress:(CBLReplication *)replication
{
    MPLog(@"Replication progress: %u", replication.status);
    [self processUpdatedBundledDataLoadReplication:replication];
}

#pragma mark - Loading bundled objects

- (NSArray *)loadBundledObjectsFromResource:(NSString *)resourceName
                              withExtension:(NSString *)extension
                           matchedToObjects:(NSArray *)preloadedObjects
                    dataChecksumMetadataKey:(NSString *)dataChecksumKey
                                      error:(NSError **)err
{
    if ([NSBundle isXPCService] || [NSBundle isCommandLineTool])
        return preloadedObjects;
    
    NSArray *returnedObjects = nil;
    MPMetadata *metadata = [self.db metadata];

    NSURL *jsonURL = [[NSBundle appBundle] URLForResource:resourceName withExtension:extension];
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
            
            __block BOOL successfullySaved = NO;
            mp_dispatch_sync(self.db.database.manager.dispatchQueue, [self.db.packageController serverQueueToken], ^{
                successfullySaved = [metadata save:err];
            });
            
            if (!successfullySaved)
                return NO;
        }
    }

    assert(returnedObjects);
    return returnedObjects;
}

#pragma mark - 

- (NSArray *)objectsMatchingQueriedView:(NSString *)view keys:(NSArray *)keys
{
    NSParameterAssert(view);
    
    CBLQuery *q = [self.db.database existingViewNamed:view].createQuery;
    q.keys = keys;
    q.prefetch = YES;
        
    return [self managedObjectsForQueryEnumerator:q.run];
}

+ (NSString *)managedObjectSingular {
    return [[self managedObjectClass] singular];
}

+ (NSString *)managedObjectPlural {
    return [[self managedObjectClass] plural];
}

@end

@implementation MPManagedObjectsController (Protected)

- (void)willSaveObject:(MPManagedObject *)object
{
    assert(object.controller == self);
    assert(self.db);
    //MPLog(@"Will save object %@", object);
}

- (void)didSaveObject:(MPManagedObject *)object
{
    assert(object.controller == self);
    assert(self.db);
    
    #ifdef DEBUG
    mp_dispatch_sync(self.db.database.manager.dispatchQueue, [self.packageController serverQueueToken], ^{
        MPLog(@"Did save object %@ in %@", object, self.db.database.internalURL);
    });
    #endif

    NSNotificationCenter *nc = [_packageController notificationCenter]; assert(nc);

    NSString *recentChange = [NSNotificationCenter notificationNameForRecentChangeOfType:MPChangeTypeAdd
                                                                   forManagedObjectClass:[object class]];

    NSString *pastChange = [NSNotificationCenter notificationNameForPastChangeOfType:MPChangeTypeAdd
                                                               forManagedObjectClass:[object class]];
    
    [nc postNotificationName:recentChange object:object];

    [nc postNotificationName:pastChange object:object];

    if ([[self.packageController delegate] conformsToProtocol:@protocol(MPDatabasePackageControllerDelegate)]
        && [[self.packageController delegate] respondsToSelector:@selector(updateChangeCount:)])
        [(id<MPDatabasePackageControllerDelegate>)[self.packageController delegate] updateChangeCount:NSChangeDone];
}

- (void)didUpdateObject:(MPManagedObject *)object
{
    assert(object.controller == self);
    assert([object isKindOfClass:[self managedObjectClass]]);
    assert(self.db);
    MPLog(@"Did change object %@", object);
    NSNotificationCenter *nc = [_packageController notificationCenter]; assert(nc);

    NSString *recentChange = [NSNotificationCenter notificationNameForRecentChangeOfType:MPChangeTypeUpdate forManagedObjectClass:[object class]];
    NSString *pastChange = [NSNotificationCenter notificationNameForPastChangeOfType:MPChangeTypeUpdate forManagedObjectClass:[object class]];

    [nc postNotificationName:recentChange object:object];
    [nc postNotificationName:pastChange object:object];

    if ([[self.packageController delegate] conformsToProtocol:@protocol(MPDatabasePackageControllerDelegate)]
        && [[self.packageController delegate] respondsToSelector:@selector(updateChangeCount:)])
        [(id<MPDatabasePackageControllerDelegate>)[self.packageController delegate] updateChangeCount:NSChangeDone];
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

    if ([[self.packageController delegate] conformsToProtocol:@protocol(MPDatabasePackageControllerDelegate)]
        && [[self.packageController delegate] respondsToSelector:@selector(updateChangeCount:)])
        [(id<MPDatabasePackageControllerDelegate>)[self.packageController delegate] updateChangeCount:NSChangeDone];
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
    NSString *recentChangeName
        = [NSNotificationCenter notificationNameForRecentChangeOfType:changeType
                                                forManagedObjectClass:[object class]];
    
    NSString *pastChangeName
        = [NSNotificationCenter notificationNameForPastChangeOfType:changeType
                                              forManagedObjectClass:[object class]];
        
    [nc postNotificationName:recentChangeName object:object userInfo:changeDict];
    [nc postNotificationName:pastChangeName object:object userInfo:changeDict];
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
    assert([mo isKindOfClass:self.managedObjectClass]);
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

#pragma mark - Scripting support

- (NSString *)objectSpecifierKey {
    return [[NSStringFromClass(self.class) stringByReplacingOccurrencesOfRegex:@"^MP" withString:@""] camelCasedString];
}

- (NSScriptObjectSpecifier *)objectSpecifier {
    assert(self.packageController);
    NSScriptObjectSpecifier *parentSpec = [self.packageController objectSpecifier];
    assert(parentSpec);
    
    NSScriptClassDescription *desc
        = [NSScriptClassDescription classDescriptionForClass:[self.packageController class]];
    
    return [[NSPropertySpecifier alloc] initWithContainerClassDescription:desc
                                                       containerSpecifier:parentSpec key:self.objectSpecifierKey];
}

- (NSDictionary *)scriptingProperties {
    return @{
                @"packageController":self.packageController
            };
}

- (id)valueInManagedObjectsWithUniqueID:(NSString *)uniqueID {
    return [self objectWithIdentifier:uniqueID];
}

- (id)scriptingValueForSpecifier:(NSScriptObjectSpecifier *)objectSpecifier {
    if ([objectSpecifier isKindOfClass:NSWhoseSpecifier.class]) {
        NSWhoseSpecifier *spec = (NSWhoseSpecifier *)objectSpecifier;
        return [super scriptingValueForSpecifier:spec];
    }
    
    return [super scriptingValueForSpecifier:objectSpecifier];
}

+ (NSArray *)singularSearchSelectorStringsForManagedObjectProperty:(NSString *)property {
    return @[ [NSString stringWithFormat:@"%@For%@:", self.managedObjectSingular, property.sentenceCasedString],
              [NSString stringWithFormat:@"%@With%@:", self.managedObjectSingular, property.sentenceCasedString],
              [NSString stringWithFormat:@"%@By%@:", self.managedObjectSingular, property.sentenceCasedString],
              [NSString stringWithFormat:@"objectBy%@:", property.sentenceCasedString],
              [NSString stringWithFormat:@"objectWith%@:", property.sentenceCasedString],
              [NSString stringWithFormat:@"objectFor%@:", property.sentenceCasedString]];
}

+ (NSArray *)pluralSearchSelectorStringsForManagedObjectProperty:(NSString *)property {
    return @[ [NSString stringWithFormat:@"%@For%@:", self.managedObjectPlural, property.sentenceCasedString],
              [NSString stringWithFormat:@"%@With%@:", self.managedObjectPlural, property.sentenceCasedString],
              [NSString stringWithFormat:@"%@By%@:", self.managedObjectPlural, property.sentenceCasedString],
              [NSString stringWithFormat:@"objectsBy%@:", property.sentenceCasedString],
              [NSString stringWithFormat:@"objectsWith%@:", property.sentenceCasedString],
              [NSString stringWithFormat:@"objectsFor%@:", property.sentenceCasedString]];
}

- (SEL)searchSelectorForManagedObjectProperty:(NSString *)property isPlural:(BOOL *)plural {
    for (NSString *selStr in [self.class pluralSearchSelectorStringsForManagedObjectProperty:property]) {
        SEL sel = NSSelectorFromString(selStr);
        
        if ([self respondsToSelector:sel]) {
            if (plural)
                *plural = YES;
            
            return sel;
        }
    }
    
    for (NSString *selStr in [self.class singularSearchSelectorStringsForManagedObjectProperty:property]) {
        SEL sel = NSSelectorFromString(selStr);
        
        if ([self respondsToSelector:sel]) {
            if (plural)
                *plural = NO;
            
            return sel;            
        }
    }
    
    return nil;
}

- (id)handleSearchCommand:(NSScriptCommand *)command {
    NSDictionary *props = command.evaluatedArguments[@"WithProperties"];
    
    NSMutableSet *results = nil;
    
    BOOL pluralsWereInvolved = NO;
    for (NSString *key in props) {
        
        
        BOOL isPlural = NO;
        SEL searchSel = [self searchSelectorForManagedObjectProperty:key isPlural:&isPlural];
        
        if (isPlural)
            pluralsWereInvolved = YES;
        
        NSAssert(searchSel, @"No search selector for property %@", key);
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id propResults = [self performSelector:searchSel withObject:props[key]];
        #pragma clang diagnostic pop
        
        if (!results) {
            if (props.count == 1) {
                return propResults; // let's return directly from here as the objects are in correct sort order and there was just a single criterion.
            } else {
                results = [NSMutableSet setWithArray:isPlural ? propResults : @[ propResults ]];
            }
        }
        else
            [results intersectSet:[NSSet setWithArray:isPlural ? propResults : @[ propResults ]]];

    }
    
    BOOL allComparable = YES;
    id anyObj = [results anyObject];
    
    for (id obj in results) {
        if (![obj respondsToSelector:@selector(compare:)] || ![obj isKindOfClass:[anyObj class]]) {
            allComparable = NO;
            break;
        }
    }
    
    if (!pluralsWereInvolved) {
        return [results anyObject];
    }
    else if (allComparable)
        return [results.allObjects sortedArrayUsingSelector:@selector(compare:)];
    else
        return [results allObjects];
}

- (void)insertValue:(id)value atIndex:(NSUInteger)index inPropertyWithKey:(NSString *)key {
    // needed, otherwise scripting system will attempt to use KVC to modify the property with the key, which is in all cases nonsensical.
}

- (void)insertValue:(id)value inPropertyWithKey:(NSString *)key {
    // needed, otherwise scripting system will attempt to use KVC to modify the property with the key, which is in all cases nonsensical.
}

- (id)newScriptingObjectOfClass:(Class)objectClass forValueForKey:(NSString *)key withContentsValue:(id)contentsValue properties:(NSDictionary *)properties
{
    // note that managed objects controllers
    // with multiple concrete subclasses of objects to manage will need a specific element to be able to create them. For instance 'tell styles controller to make new managed object' would not work as styles controller has multiple managed object types it manages, same thing with elements controller. would instead want to do 'tell styles controller to make new paragraph style'
    assert([objectClass isSubclassOfClass:self.managedObjectClass]);
    MPManagedObject *obj = [[objectClass alloc] initWithNewDocumentForController:self properties:@{} documentID:nil];
    
    [obj setScriptingDerivedProperties:properties];
    [obj save];
    
    return obj;
}

@end


@implementation CBLDocument (MPManagedObjectExtensions)

- (Class)managedObjectClass
{
    __block NSString *objectType = nil;
    mp_dispatch_sync(self.database.manager.dispatchQueue, [self.database.packageController serverQueueToken], ^{
        objectType = self.properties[@"objectType"];
    });
    assert(objectType);
    return NSClassFromString(objectType);
}

- (NSURL *)URL
{
    NSURL *URL = [self.database.internalURL URLByAppendingPathComponent:self.documentID];
    return URL;
}

@end