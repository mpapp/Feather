//
//  MPManagedObjectsController.m
//  Feather
//
//  Created by Matias Piipari on 16/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import FeatherExtensions;

#import <Feather/MPManagedObject+Protected.h>

#import "MPManagedObjectsController+Protected.h"

#import "MPDatabasePackageController.h"
#import "MPDatabasePackageController+Protected.h"

#import "NSDictionary+MPManagedObjectExtensions.h"

#import "MPException.h"
#import "MPDatabase.h"

#import "MPShoeboxPackageController.h"

@import CouchbaseLite;
@import ObjectiveC;

#import "MPCacheableMixin.h"

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

+ (void)load
{
    // [self mixinFrom:[MPCacheableMixin class] followInheritance:NO force:NO];
}

+ (BOOL)hasMainThreadIsolatedCachedProperties {
    return NO;
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
        __weak typeof(self) weakSelf = self;
        id (^allObjectsForObjectSpecifierKey)(void) = ^id() {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            return [strongSelf allObjects];
        };
        
        //NSLog(@"Implementing '%@'", allObjectsSpecifierKey);
        
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
    
    // only load bundled data if the database itself is not intended to be started from bootstrapped data.
    if (![self.packageController bootstrapDatabaseURLForDatabaseWithName:self.db.name]) {
        if (![self loadBundledDatabaseResources:error])
            return NO;
        
        if (![self loadBundledJSONResources:error])
            return NO;
    }
    
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

+ (NSDictionary *)managedObjectClassByControllerClassNameDictionary {
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

+ (Class)equivalenceClassForManagedObjectClass:(Class)moClass {
    NSAssert([moClass isSubclassOfClass:MPManagedObject.class], @"Expecting subclass of MPManagedObject, but encountered: \%@", moClass);
    
    static NSDictionary *classDict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary *d = [NSMutableDictionary new];
        for (Class mocClass in MPManagedObjectsController.subclasses) {
            Class oClass = mocClass.managedObjectClass;
            
            for (Class oSubclass in [oClass.subclasses arrayByAddingObject:oClass]) {
                NSString *oSubclassName = NSStringFromClass(oSubclass);
                d[oSubclassName] = mocClass;
            }
            
        }
        
        classDict = d.copy;
    });
    
    NSString *classString = NSStringFromClass(moClass);
    classString = [classString stringByReplacingOccurrencesOfString:@"NSKVONotifying_" withString:@""]; // ugh.
    Class equivalenceClass = [classDict[classString] managedObjectClass];
    NSAssert(equivalenceClass != nil && [equivalenceClass isSubclassOfClass:MPManagedObject.class], @"Unexpected equivalence class '%@'", equivalenceClass);
    return equivalenceClass;
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

        //NSLog(@"Subclasses of %@: %@", NSStringFromClass(cls), subclasses);

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

    if (!objectType)
        return NO;
    
    return [self.managedObjectSubclasses containsObject:objectType];
}

- (BOOL)managesDocumentWithIdentifier:(NSString *)documentID {
    NSString *clsString = NSStringFromClass([MPManagedObject managedObjectClassFromDocumentID:documentID]);
    return [self.managedObjectSubclasses containsObject:clsString];
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
- (BOOL)resolveConflictingRevisionsForObject:(MPManagedObject *)obj
                                       error:(NSError **)err
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
    return [rev createRevisionWithProperties:rev.properties error:err] != nil;
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
    
    [[self.db.database viewNamed:[self userContributedObjectsViewName]]
     setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit)
     {
         if (![self managesDocumentWithDictionary:doc])
             return;
         
         if (!doc[@"userContributed"] || ![doc[@"userContributed"] boolValue]) {
             return;
         }
         
         emit(doc.managedObjectDocumentID, nil);
     } version:@"1.3"];
    
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
        BOOL managesBasedOnDict = [strongSelf managesDocumentWithDictionary:revision.properties];
        BOOL managesBasedOnID = NO;
        
        if (!managesBasedOnDict) {
            
            // try finding _id and determining object type based on it.
            // this should only be necessary for deletions, otherwise data is malformed (lacks 'objectType').
            managesBasedOnID = [strongSelf managesDocumentWithIdentifier:revision.properties[@"_id"]];
            if (managesBasedOnID) {
                NSCAssert(revision.properties[@"_deleted"] || [revision isDeletion],
                          @"Expecting revision to be a deletion:\n%@", revision.properties);
            }
        }
        
        return managesBasedOnDict || managesBasedOnID;
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

- (NSString *)userContributedObjectsViewName {
    return [NSString stringWithFormat:@"%@-user-contributed", NSStringFromClass(self.class)];
}

- (NSArray *)userContributedObjects {
    return [self objectsMatchingQueriedView:[self userContributedObjectsViewName] keys:nil];
}

- (NSArray *)allObjects:(NSError **)error
{
    CBLQuery *q = [self allObjectsQuery];
    
    __block NSArray *objs;
    objs = [self managedObjectsForQueryEnumerator:[q run:error]];
    
    return objs;
}

- (NSArray *)objects {
    return self.allObjects;
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

#if DEBUG
- (CBLDocument *)possiblyDeletedDocumentWithIdentifier:(NSString *)identifier
{
    return [self documentWithIdentifier:identifier allDocsMode:kCBLIncludeDeleted];
}
#endif

- (CBLDocument *)documentWithIdentifier:(NSString *)identifier
                            allDocsMode:(CBLAllDocsMode)allDocsMode {
    NSParameterAssert(identifier);
    
    CBLQuery *allObjectsQ = [self.db.database createAllDocumentsQuery];
    allObjectsQ.keys = @[identifier];
    allObjectsQ.prefetch = YES;
    allObjectsQ.allDocsMode = allDocsMode;
    
    NSMutableArray *docs = [NSMutableArray new];
    for (CBLQueryRow *row in allObjectsQ.run) {
        [docs addObject:row.document];
    }
    
    return docs.firstObject;
}

- (id)objectWithIdentifier:(NSString *)identifier
{
    NSAssert(identifier, @"Expecting a non-nil identifier parameter.");
    NSAssert([[MPManagedObject managedObjectClassFromDocumentID:identifier] isSubclassOfClass:self.managedObjectClass],
             @"Identifier is for an unexpected kind of object: %@ (%@)", identifier, self);
    
    __block MPManagedObject *mo = _objectCache[identifier];
    if (mo)
    {
        NSAssert(mo.controller == self, @"Object has unexpected controller: %@", mo.controller);
        NSAssert([mo isKindOfClass:self.managedObjectClass], @"Object is of unexpected kind: %@", mo);
        return mo;
    }
    
    NSAssert(identifier, @"Expecting identifier: %@", identifier);
    Class cls = [MPManagedObject managedObjectClassFromDocumentID:identifier];
    NSAssert(cls, @"Class unexpectedly missing from document ID: %@", identifier);
    
    __block CBLDocument *doc = nil;
    
    mp_dispatch_sync(self.db.database.manager.dispatchQueue,
                     [self.packageController serverQueueToken], ^{
        doc = [self.db.database existingDocumentWithID:identifier];
    });
    
    if (!doc) {
        if (!self.relaysFetchingByIdentifier
            || self.packageController == MPShoeboxPackageController.sharedShoeboxController) {
            MPLog(@"WARNING! Failed to find object by ID: %@", identifier);
            return nil;
        }
        
        MPManagedObjectsController *moc
            = [[MPShoeboxPackageController sharedShoeboxController] controllerForManagedObjectClass:cls];
        NSAssert(moc != self, @"Attempting to recursively get object by ID from self.");
        
        return [moc objectWithIdentifier:identifier];
    }
    
    mp_dispatch_sync(self.db.database.manager.dispatchQueue,
                     [self.packageController serverQueueToken],
    ^{
        if ((mo = (id)[doc modelObject])) {
            
            if (![doc isDeleted]) {
                NSAssert(mo, @"Model object could not be recovered / constructed for non-deleted document %@ (%@)", doc, [doc properties]);
            }
            
            if (mo) {
                return;
            }
        }
        
        // this branch may be unnecessary and we should try to do without.
        
        // if object is deleted, mo is left nil and ultimately returned.
        if (![doc isDeleted]) {
            mo = [cls modelForDocument:doc];
            NSAssert(mo, @"Model object could not be recovered / constructed for non-deleted document %@ (%@)", doc, [doc properties]);
        }
    });
    
    if (mo) {
        NSAssert(mo.controller == self, @"Object %@ has unexpected controller: %@", mo, mo.controller);
        NSAssert([mo isKindOfClass:self.managedObjectClass], @"Object is of unexpected kind: %@, (%@)", mo, mo.class);
    }
    return mo;
}

- (BOOL)relaysFetchingByIdentifier {
    return NO;
}

- (id)newObjectOfClass:(Class)cls {
    if (!cls) {
        cls = [[self class] managedObjectClass];
    }
    
    NSString *className = NSStringFromClass(cls);
    NSParameterAssert([cls isSubclassOfClass:self.managedObjectClass]);
               
    MPManagedObject *obj = [[cls alloc] initWithNewDocumentForController:self];
    obj.objectType = className;
    obj.autosaves = [self autosavesObjects];
    
    return obj;
}

- (id)newObject {
    return [self newObjectOfClass:nil];
}

- (Class)prototypeClass {
    return self.managedObjectClass;
}

- (id)newObjectWithPrototype:(MPManagedObject *)prototype documentID:(NSString *)documentID
{
    NSAssert(prototype, @"Expecting a non-nil prototype for object of class %@", self.class);
    NSAssert([prototype isKindOfClass:self.prototypeClass], @"Unexpected prototype class %@. Expected: %@", prototype.class, self.prototypeClass);
    NSAssert(prototype.canFormPrototype, @"Object of class %@cannot form prototype: %@", prototype.class, prototype.propertiesToSave);
    NSAssert(prototype.document.documentID, @"Prototype should have a documentID: %@ (%@)", prototype, prototype.document);

    // TODO: might need also -prototypeInstanceClassForPrototype: if this appears insufficient.
    Class instantiableClass = self.prototypeClass == self.managedObjectClass
                                ? prototype.class
                                : self.managedObjectClass;
    
    MPManagedObject *obj = [[instantiableClass alloc] initWithNewDocumentForController:self prototype:prototype documentID:documentID];
    obj.prototype = prototype;

    for (NSString *key in prototype.document.userProperties)
    {
        id transformedValue = [prototype prototypeTransformedValueForPropertiesDictionaryKey:key forCopyOfPrototypeObject:obj];
        [obj setValue:transformedValue ofProperty:key];
    }
    
    // need to save before attaching, otherwise attaching will fail (as there's nothing to attach to).
    if (prototype.attachmentNames) {
        [obj save];
    }
    
    [prototype.attachmentNames enumerateObjectsUsingBlock:^(NSString *attachmentName, NSUInteger idx, BOOL *stop) {
        CBLAttachment *attachment = [prototype attachmentNamed:attachmentName];
        if (attachment.contentType && attachment.content) {
            [obj setAttachmentNamed:attachment.name withContentType:attachment.contentType content:attachment.content];
            [obj save];
        }
    }];

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
    NSData *objData = [NSData dataWithContentsOfURL:url options:0 error:err];
    if (!objData) {
        if (*err) {
            NSLog(@"Failed to read data from URL %@: %@", url, *err);
        }
        return nil;
    }

    return [self objectsFromArrayJSONData:objData error:err];
}

- (NSArray *)objectsFromArrayJSONData:(NSData *)objData error:(NSError *__autoreleasing *)err
{
    NSArray *objs = [NSJSONSerialization JSONObjectWithData:objData options:NSJSONReadingAllowFragments error:err];
    if (!objs) {
        if (*err) {
            NSLog(@"Failed to deserialize JSON: %@", *err);
            NSLog(@"Invalid data:\n%@", [[NSString alloc] initWithData:objData encoding:NSUTF8StringEncoding]);
        }
        return nil;
    }
    
    return [self objectsFromJSONEncodableObjectArray:objs error:err];
}

- (NSArray *)objectsFromJSONEncodableObjectArray:(NSArray *)objs error:(NSError **)err
{
    NSMutableArray *mos = [NSMutableArray arrayWithCapacity:objs.count];
    for (NSMutableDictionary *d in objs)
    {
        BOOL isExisting = NO;
        MPManagedObject *mo = [self objectFromJSONDictionary:d isExisting:&isExisting error:err];
        
        if (!mo) {
            NSLog(@"Failed to construct managed object from JSON dictionary %@", d);
            return nil;
        }
        
        if (mo.needsSave || !isExisting) {
            [mos addObject:mo];
        }
    }
    
    if (mos.count > 0) {
        NSError *e = nil;
        
        NSSet *docIDs = [NSSet setWithArray:[mos valueForKey:@"documentID"]];
        
        if (docIDs.count != mos.count) {
            NSMutableDictionary *counts = @{}.mutableCopy;
            for (NSString *docID in [mos valueForKey:@"documentID"]) {
                counts[docID] = @([counts[docID] unsignedIntegerValue] + 1);
            }
            
            for (id k in [counts.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
                return [a compare:b];
            }]) {
                if ([counts[k] unsignedIntegerValue] > 1) {
                    NSLog(@"ERROR! Duplicate template with ID '%@'", k);
                }
            }
            
            NSAssert(docIDs.count == mos.count, @"There should be no duplicate document IDs amongst the saved objects.");
        }
        
        if (![MPManagedObject saveModels:mos error:&e]) {
            if (err) {
                *err = e;
            }
            
            return nil;
        }
    }
    
    return mos.copy;
}

- (MPManagedObject *)objectFromJSONDictionary:(NSDictionary *)d isExisting:(BOOL *)isExisting error:(NSError **)err
{
    if (![d isManagedObjectDictionary:err]) {
        NSLog(@"ERROR: %@", *err);
        return nil;
    }
    
    NSString *docID = [d managedObjectDocumentID];
    NSAssert(docID, @"Expecting document ID in dictionary: %@", d);
    
    Class moClass = NSClassFromString([d managedObjectType]);
    NSAssert(moClass, @"Expecting object type in dictionary: %@", d);
    
    __block CBLDocument *doc = nil;
    mp_dispatch_sync([(CBLManager *)[self.packageController server] dispatchQueue],
                     [self.packageController serverQueueToken], ^{
                         doc = [self.db.database existingDocumentWithID:docID];
                     });
    
    MPManagedObject *mo = doc ? [moClass modelForDocument:doc] : nil;
    
    if (mo) {
        [mo setValuesForPropertiesWithDictionary:d];
        if (mo.needsSave && isExisting)
            *isExisting = YES;
    }
    else {
        Class moc = NSClassFromString([d managedObjectType]);
        assert(moc);
        mo = [[moc alloc] initWithNewDocumentForController:self properties:d documentID:docID];
    }
    
    NSAssert(mo, @"Could not recover model object from JSON dictionary %@", d);
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
                modelObj = self->_objectCache[row.document.documentID];
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
    mp_dispatch_sync(self.db.database.manager.dispatchQueue, [self.packageController serverQueueToken], ^{
        for (CBLQueryRow* row in rows)
        {
            MPManagedObject *modelObj = (MPManagedObject *)[row.document modelObject];
            
            if (!modelObj) {
                modelObj = self->_objectCache[row.document.documentID];
                modelObj.document = row.document;
                
                if (!modelObj) {
                    if (![row.document isDeleted]) {
                        modelObj = [[row.document managedObjectClass] modelForDocument:row.document];
                    }
                }
            }
            else {
                NSAssert(modelObj.document == row.document,
                         @"Unexpected row.document: %@ != %@ (%@ ; %@)",
                         modelObj.document, row.document,
                         modelObj.propertiesToSave, row.document.properties);
            }
            
            if (modelObj) {
                NSAssert([modelObj isKindOfClass:[MPManagedObject class]],
                         @"Model object is of unexpected class: %@", modelObj);
                
                [entries addObject:modelObj];
            }
        }
    });
    
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

- (NSString *)bundledResourceExtension {
    return @".json";
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
                               withExtension:self.bundledResourceExtension
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
    NSString *bundledManuscriptDataDirectory = MPStringF(@"%@.manuscripts-data", self.bundledResourceDatabaseName);
    
    NSString *bundledBundlesPath = [[self resourcesBundle] pathForResource:self.bundledResourceDatabaseName ofType:@"cblite" inDirectory:bundledManuscriptDataDirectory];
    NSString *bundledAttachmentsPath = [[self resourcesBundle] pathForResource:attachmentsDirectoryName ofType:@"" inDirectory:bundledManuscriptDataDirectory];
    
    NSError *err = nil;
    NSURL *tempBundledBundlesDirURL = [fm temporaryDirectoryURLInGroupCachesSubdirectoryNamed:checksumKey error:&err];
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
    
    NSString *previousChecksumValue = [metadata getValueOfProperty:checksumKey];
    BOOL previousValueExists = previousChecksumValue != nil;
    BOOL previousValueMatchesCurrentChecksum = [previousChecksumValue isEqualToString:md5];
    if (previousValueMatchesCurrentChecksum) {
        return YES;
    }
    
    if (![fm copyItemAtPath:bundledBundlesPath toPath:tempBundledBundlesPath error:error])
        return NO;
    
    if ([fm fileExistsAtPath:bundledAttachmentsPath])
        if (![fm copyItemAtPath:bundledAttachmentsPath toPath:tempAttachmentsPath error:error])
            return NO;
    
    // if a previous version was loaded, purge the current version and then proceed with the pull below.
    // NOTE! This may fail, but failure will be communicated downstream.
    if (previousValueExists && !previousValueMatchesCurrentChecksum) {
        NSError *__block e = nil;
        __block BOOL purgingFailed = NO;
        [self.allObjects enumerateObjectsUsingBlock:^(MPManagedObject *mo, NSUInteger idx, BOOL *stop) {
            if (![mo.document purgeDocument:&e]) {
                purgingFailed = YES;
                *stop = YES;
            }
        }];
        
        if (purgingFailed) {
            if (error)
                *error = e;
            return NO;
        }
    }
    
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
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
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
            self->_loadingBundledDatabaseResources = NO;
        });
    }
}

- (void)replicationDidProgress:(CBLReplication *)replication
{
    MPLog(@"Replication progress: %u", replication.status);
    [self processUpdatedBundledDataLoadReplication:replication];
}

#pragma mark - Loading bundled objects

- (NSBundle *)resourcesBundle
{
    return [NSBundle bundleForClass:self.class];    // can optionally override in subclasses
}

- (NSArray *)loadBundledObjectsFromResource:(NSString *)resourceName
                              withExtension:(NSString *)extension
                           matchedToObjects:(NSArray *)preloadedObjects
                    dataChecksumMetadataKey:(NSString *)dataChecksumKey
                                      error:(NSError *__nullable __autoreleasing *__nullable)err
{
    if ([NSBundle isXPCService] || [NSBundle isCommandLineTool])
        return preloadedObjects;
    
    NSArray *returnedObjects = nil;
    MPMetadata *metadata = [self.db metadata];

    NSURL *jsonURL = [[self resourcesBundle] URLForResource:resourceName withExtension:extension];
    NSAssert(jsonURL, @"Could not find resource '%@' with extension '%@'", resourceName, extension);
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *md5 = [fm md5DigestStringAtPath:[jsonURL path]];

    if ([md5 isEqualToString:[metadata getValueOfProperty:dataChecksumKey]])
    {
        returnedObjects = preloadedObjects;
        NSAssert(returnedObjects, @"Expecting non-nil objects for resource name %@", resourceName);
    }
    else
    {
        returnedObjects = [self objectsFromContentsOfArrayJSONAtURL:jsonURL error:err];

        if (!returnedObjects)
        {
            if (err && *err) {
                NSLog(@"ERROR! Could not load bundled data from resource %@%@:\n%@", resourceName, extension, *err);
                [NSNotificationCenter.defaultCenter postErrorNotification:*err];
            }
            return nil;
        }
        else if (returnedObjects)
        {
            [metadata setValue:md5 ofProperty:dataChecksumKey];
            
            __block BOOL successfullySaved = NO;
            mp_dispatch_sync(self.db.database.manager.dispatchQueue, [self.db.packageController serverQueueToken], ^{
                successfullySaved = [metadata save:err];
            });
            
            if (!successfullySaved) {
                return nil;
            }
        }
    }

    assert(returnedObjects);
    return returnedObjects;
}

#pragma mark - 

- (NSArray *)objectsMatchingQueriedView:(NSString *)view keys:(NSArray *)keys {
    // Assertions here are safe because query may be sent once database is already torn down during shutdown.
    //NSParameterAssert(view);
    
    CBLQuery *q = [self.db.database existingViewNamed:view].createQuery;
//#ifdef DEBUG
//    NSParameterAssert(q);
//#endif
    
    if (!q) {
        MPLog(@"WARNING! No view with name '%@' in database %@ (%@)", view, self.db.name, self.db.database);
        return nil;
    }
    
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
    
    NSNotificationCenter *nc = [_packageController notificationCenter];
    NSAssert(nc, @"Expecting to have a package controller + notification center for object: %@ (%@)",
             object, _packageController);

    NSString *recentChange = [NSNotificationCenter notificationNameForRecentChangeOfType:MPChangeTypeAdd
                                                                   forManagedObjectClass:[object class]];

    NSString *pastChange = [NSNotificationCenter notificationNameForPastChangeOfType:MPChangeTypeAdd
                                                               forManagedObjectClass:[object class]];
    
    [nc postNotificationName:recentChange object:object
                    userInfo:@{@"source":@(MPManagedObjectChangeSourceInternal)}];

    [nc postNotificationName:pastChange object:object
                    userInfo:@{@"source":@(MPManagedObjectChangeSourceInternal)}];

    if ([[self.packageController delegate] conformsToProtocol:@protocol(MPDatabasePackageControllerDelegate)]
        && [[self.packageController delegate] respondsToSelector:@selector(updateChangeCount:)])
        [(id<MPDatabasePackageControllerDelegate>)[self.packageController delegate] updateChangeCount:NSChangeDone];
}

- (void)didUpdateObject:(MPManagedObject *)object
{
    assert(object.controller == self);
    assert([object isKindOfClass:[self managedObjectClass]]);
    assert(self.db);
    //MPLog(@"Did change object %@", object);
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
    NSParameterAssert([mo isKindOfClass:[self managedObjectClass]]);
    NSParameterAssert(_objectCache);
    if (mo.document.documentID && _objectCache[mo.document.documentID] == mo) {
        [_objectCache removeObjectForKey:mo.document.documentID];
    }
}

#pragma mark - Scripting support

- (NSString *)objectSpecifierKey {
    return [[NSStringFromClass(self.class) stringByReplacingOccurrencesOfRegex: @"^MP" withTemplate: @"" error: nil] camelCasedString];
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

@end


@implementation CBLDocument (MPManagedObjectExtensions)

- (Class)managedObjectClass
{
    __block NSString *objectType = nil;
    mp_dispatch_sync(self.database.manager.dispatchQueue, [self.database.packageController serverQueueToken], ^{
        objectType = self.properties[@"objectType"];
    });
    NSAssert(objectType, @"Unexpected nil objectType: %@ (%@)", self.properties, self.documentID);
    return NSClassFromString(objectType);
}

- (NSURL *)URL
{
    NSURL *URL = [self.database.internalURL URLByAppendingPathComponent:self.documentID];
    return URL;
}

@end
