//
//  MPManagedObject.m
//  Feather
//
//  Created by Matias Piipari on 16/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Feather/MPManagedObject+Protected.h>

#import "MPDatabase.h"
#import "MPManagedObject.h"
#import "MPManagedObjectsController.h"

#import "MPManagedObjectsController+Protected.h"

#import "MPDatabasePackageController.h"
#import "MPDatabasePackageController+Protected.h"
#import "MPShoeboxPackageController.h"

#import "NSNotificationCenter+MPExtensions.h"

#import "MPEmbeddedObject.h"
#import "MPEmbeddedObject+Protected.h"
#import "MPEmbeddedPropertyContainingMixin.h"

#import "MPEmbeddedObject.h"

#import "MPContributor.h"
#import "MPContributorsController.h"
#import "MPShoeboxPackageController.h"

#import "NSObject+MPExtensions.h"
#import "NSArray+MPExtensions.h"
#import "NSDictionary+MPExtensions.h"
#import "NSObject+MPExtensions.h"
#import "NSFileManager+MPExtensions.h"
#import "NSDictionary+MPManagedObjectExtensions.h"

#import "NSString+MPSearchIndex.h"

#import "Mixin.h"
#import "MPCacheableMixin.h"

#import "RegexKitLite.h"
#import <CouchCocoa/CouchCocoa.h>

#import <objc/runtime.h>
#import <objc/message.h>

NSString * const MPManagedObjectErrorDomain = @"MPManagedObjectErrorDomain";

#if MP_DEBUG_ZOMBIE_MODELS
static NSMapTable *_modelObjectByIdentifierMap = nil;
#endif

@interface MPManagedObject ()
{
    __weak MPManagedObjectsController *_controller;
    NSString *_newDocumentID;
}

@property (readwrite) BOOL isNewObject;

@property (readwrite, strong) NSMutableDictionary *embeddedObjectCache;

@property (readonly, copy) NSString *deletedDocumentID;

@end

@implementation MPReferencableObjectMixin
@end

@implementation MPManagedObject
@synthesize controller = _controller;

+ (void)initialize
{
    if (self == [MPManagedObject class])
    {
        [self mixinFrom:[MPCacheableMixin class]];
        [self mixinFrom:[MPEmbeddedPropertyContainingMixin class]];
        
#if MP_DEBUG_ZOMBIE_MODELS
        _modelObjectByIdentifierMap = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory
                                                            valueOptions:NSPointerFunctionsWeakMemory];
#endif
    }
}

#if MP_DEBUG_ZOMBIE_MODELS
+ (void)clearModelObjectMap { [_modelObjectByIdentifierMap removeAllObjects]; }
#endif

- (instancetype)init
{
    assert(false);
    @throw [NSException exceptionWithName:@"MTInvalidInitException" reason:nil userInfo:nil];
    return nil;
}

- (void)dealloc
{
#ifdef MP_DEBUG_DEALLOC
    MPLog(@"Deallocating %@", self);
#endif
    
    if (_controller)
        [_controller deregisterObject:self];
}

/* Looks to be used from within CouchPersistentReplication? Needs some adjusting. - Matias */
- (instancetype)initWithNewDocumentInDatabase:(CouchDatabase*)database
{
    assert(false);
    @throw [NSException exceptionWithName:@"MTInvalidInitException" reason:nil userInfo:nil];
    return nil;
}

- (instancetype)initWithDocument:(CouchDocument*)document
{
    if (self = [super initWithDocument:document])
    {

#if MP_DEBUG_ZOMBIE_MODELS
        if (document)
        {
            assert(![_modelObjectByIdentifierMap objectForKey:self.document.documentID]
                   || ([_modelObjectByIdentifierMap objectForKey:self.document.documentID] == self));
            [_modelObjectByIdentifierMap setObject:self forKey:document.documentID];
        }
#endif

        assert(_controller);
        self.isNewObject = document == nil; // is new if there's no document to go with it.
        [self didInitialize];
    } else {
        assert(false);
        return nil;
    }
    return self;
}

- (instancetype)initWithNewDocumentForController:(MPManagedObjectsController *)controller
{
    return [self initWithNewDocumentForController:controller properties:nil documentID:nil];
}

- (instancetype)initWithNewDocumentForController:(MPManagedObjectsController *)controller properties:(NSDictionary *)properties
{
    return [self initWithNewDocumentForController:controller properties:properties documentID:nil];
}

- (void)didInitialize
{
    _embeddedObjectCache = [NSMutableDictionary dictionaryWithCapacity:20];
    
    assert(_controller);
    if (self.document)
        [_controller registerObject:self];
}

- (void)cacheEmbeddedObjectByIdentifier:(MPEmbeddedObject *)obj
{
    if (!obj) return;
    
    assert([obj identifier]);
    if (_embeddedObjectCache[[obj identifier]])
    {
        assert(_embeddedObjectCache[[obj identifier]] == obj); return;
    }
    
    _embeddedObjectCache[obj.identifier] = obj;
}

- (void)removeEmbeddedObjectFromByIdentifierCache:(MPEmbeddedObject *)obj
{
    if (!obj) return;
    
    assert([obj identifier]);
    
    if (_embeddedObjectCache[obj.identifier])
    {
        [_embeddedObjectCache removeObjectForKey:obj.identifier];
    }
    else
    {
        assert(false); // should not try to remove if it weren't there. remove this assertion if it looks invalid.
    }
}

- (MPEmbeddedObject *)embeddedObjectWithIdentifier:(NSString *)identifier
{
    assert(_embeddedObjectCache);
    return _embeddedObjectCache[identifier];
}

- (NSString *)documentID
{
    if (self.document) return self.document.documentID;
    else assert(_deletedDocumentID);
    return _deletedDocumentID;
}

+ (NSString *)idForNewDocumentInDatabase:(CouchDatabase *)db
{
    return [NSString stringWithFormat:@"%@:%@", NSStringFromClass([self class]), [[NSUUID UUID] UUIDString]];
}

+ (Class)managedObjectClassFromDocumentID:(NSString *)documentID
{
    assert(documentID);
    NSString *className = [documentID componentsSeparatedByString:@":"][0];
    Class moClass = NSClassFromString(className);
    assert(moClass);
    assert([moClass isSubclassOfClass:[MPManagedObject class]]);
    return moClass;
}

+ (NSString *)humanReadableName
{
    NSString *className = NSStringFromClass(self);
    return [[className componentsMatchedByRegex:@"MP(.*)" capture:1] firstObject];
}

- (NSString *)idForNewDocumentInDatabase:(CouchDatabase *)db
{
#ifdef DEBUG
    assert([self class] != [MPManagedObject class]); // should not call directly on the subclass.
    if (_newDocumentID)
    {
        BOOL hasCorrectPrefix = [_newDocumentID hasPrefix:[NSString stringWithFormat:@"%@:", NSStringFromClass(self.class)]];
        assert(hasCorrectPrefix);
    }
#endif
    return _newDocumentID ? _newDocumentID : [[self class] idForNewDocumentInDatabase:db];
}

- (void)setControllerWithDocument:(CouchDocument *)document
{
    NSString *classStr = [document propertyForKey:@"objectType"];
    assert(classStr);
    Class class = NSClassFromString(classStr);
    
    MPDatabasePackageController *packageController = [document.database packageController];
    MPManagedObjectsController *moc = [packageController controllerForManagedObjectClass:class];
    assert(moc);
    
    assert(!_controller);
    self.controller = moc;
}

+ (id)modelForDocument:(CouchDocument*)document
{
    assert(document);
    assert(document.database);
    
    if (document.modelObject) return document.modelObject;
    
    CouchModel *cm = [super modelForDocument:document];
    assert ([cm isKindOfClass:[MPManagedObject class]]);

    MPManagedObject *mo = (MPManagedObject *)cm;
    
    if (!mo.controller) [mo setControllerWithDocument:document];
    
    assert(mo.controller);
    assert([document.properties[@"objectType"] isEqualToString:NSStringFromClass(self)]);
        
    return mo;
}

- (void)updateTimestamps
{
    BOOL createdAtExists = [self createdAt] != nil;
    
    NSDate *now = [NSDate date];
    if (!createdAtExists)
    {
        assert(self.needsSave);
        [self setCreatedAt:now];
    }
    
    if (self.needsSave)
    {
        [self setUpdatedAt:now];
    }
}

+ (RESTOperation *)saveModels:(NSArray *)models
{
    for (MPManagedObject *mo in models)
    {
        assert([mo isKindOfClass:[MPManagedObject class]]);
        
        if (!mo.document.modelObject)
            mo.document.modelObject = mo;
        
        [mo updateTimestamps];
    }
    return [super saveModels:models];
}

- (RESTOperation *)save
{
    assert(_controller);
    assert(_document);
    [_controller willSaveObject:self];
    
    if (!_document.modelObject) _document.modelObject = self;
    
    [self updateTimestamps];
    
    RESTOperation *oper = [super save];
    
    // once save finishes, propagate needsSave => false through the tree
    // FIXME: race condition on concurrent saves (could set needsSave to false on an embedded key too early)
    [oper onCompletion:^{
        for (NSString *propertyKey in [[self class] embeddedProperties])
        {
            MPEmbeddedObject *embeddedObj = [self valueForKey:propertyKey];
            assert(!embeddedObj
                   || [embeddedObj isKindOfClass:MPEmbeddedObject.class]);
            [embeddedObj setNeedsSave:false];
        }
    }];
    
    return oper;
}

- (void)saveCompleted:(RESTOperation *)op {
    assert(_controller);
    
    if (self.isNewObject)
    {
        self.isNewObject = NO;
        [_controller didSaveObject:self];
    }
    else
    {
        [_controller didUpdateObject:self];
    }
}

- (RESTOperation *)deleteDocument
{
    assert(_controller);
    
    NSString *deletedDocumentID = self.document.documentID;
    assert(deletedDocumentID);
    
    RESTOperation *op = [super deleteDocument];
    [op onCompletion:^{
        
        _deletedDocumentID = deletedDocumentID;
        
        [_controller didDeleteObject:self];
        
#if MP_DEBUG_ZOMBIE_MODELS
        NSString *docID = self.document.documentID;
        
        if (docID)
            [_modelObjectByIdentifierMap removeObjectForKey:docID];
#endif
    }];
    
    return op;
}

- (void)couchDocumentChanged:(CouchDocument *)doc
{
    if ([super respondsToSelector:@selector(couchDocumentChanged:)])
        [super couchDocumentChanged:doc];

    assert(doc == self.document);
    [_controller didChangeDocument:doc forObject:self];
}

- (void)didLoadFromDocument
{
    //NSLog(@"Did load");
    NSArray *conflictingRevs = [self.document getConflictingRevisions];
    
    if (conflictingRevs.count > 1)
    {
        NSLog(@"Conflicting revisions: %@", conflictingRevs);
        [_controller resolveConflictingRevisionsForObject:self];
    }
    assert(_controller);
    [super didLoadFromDocument]; // super class implementation ought to be empty but just for safety.
    [_controller didLoadObjectFromDocument:self];
}

- (MPManagedObjectsController *)controller
{
    return _controller;
}

- (CouchDocument *)document
{
    return [super document];
}

- (void)setDocument:(CouchDocument *)document
{
    if (!_controller)
    {
        [self setControllerWithDocument:document];
    }
    
    document.modelObject = self;
    [super setDocument:document];
    
    if (self.document)
    {
        assert(_controller);
        [_controller registerObject:self];
    }
}

- (CouchAttachment *)createAttachmentWithName:(NSString *)name
                                   withString:(NSString *)string
                                         type:(NSString *)type
                                        error:(NSError **)err
{
    if (!type)
    {
        if (err)
            *err = [NSError errorWithDomain:MPManagedObjectErrorDomain
                                       code:MPManagedObjectErrorCodeTypeMissing
                                   userInfo:@{NSLocalizedDescriptionKey:
                    [NSString stringWithFormat:@"No type was given for creating attachment from string '%@'", string]}];
    }
    
    NSData *body = [string dataUsingEncoding:NSUTF8StringEncoding];
    CouchAttachment *a = [self.document.currentRevision createAttachmentWithName:name type:type];
    a.body = body;
    return a;
}

- (CouchAttachment *)createAttachmentWithName:(NSString*)name
                            withContentsOfURL:(NSURL *)url
                                         type:(NSString *)type error:(NSError **)err
{
    if (!type && [url isFileURL])
    {
        if (![[NSFileManager defaultManager] mimeTypeForFileAtURL:url error:err]) return nil;
    }

    if (!type)
    {
        if (err)
        {
            *err = [NSError errorWithDomain:MPManagedObjectErrorDomain
                                       code:MPManagedObjectErrorCodeTypeMissing
                                   userInfo:@{NSLocalizedDescriptionKey:
            [NSString stringWithFormat:@"No type was given for creating attachment from file at path %@", url]}];
        }
        return nil;
    }
    
    NSData *body = [NSData dataWithContentsOfURL:url options:0 error:err];
    if (!body) return nil;
    
    CouchAttachment *a = [self.document.currentRevision createAttachmentWithName:name type:type];
    a.body = body;
    return a;
}

#pragma mark - Accessors

- (NSString *)description
{
    return [NSString stringWithFormat:@"[%@, rev:%@]", self.document.documentID, self.document.currentRevisionID];
}

- (void)setCreatedAt:(NSDate *)createdAt { assert(createdAt); [self setValue:@([createdAt timeIntervalSince1970]) ofProperty:@"createdAt"]; }
- (NSDate *)createdAt
{
    id createdAtVal = [self getValueOfProperty:@"createdAt"];
    if (!createdAtVal) return nil;
    NSTimeInterval createdAt = [createdAtVal doubleValue];
    return [NSDate dateWithTimeIntervalSince1970:createdAt];
}

- (void)setUpdatedAt:(NSDate *)updatedAt
{
    assert(updatedAt);
    [self setValue:@([updatedAt timeIntervalSince1970]) ofProperty:@"updatedAt"];
}
- (NSDate *)updatedAt
{
    id updatedAtVal = [self getValueOfProperty:@"updatedAt"];
    if (!updatedAtVal) return nil;
    return [NSDate dateWithTimeIntervalSince1970:[updatedAtVal doubleValue]];
}

- (void)setShared:(BOOL)shared {
    BOOL prevValue = [self isShared];
    if (prevValue == shared) return;
    if (!shared) assert(!prevValue); // object cannot be un-shared
    
    [self setValue:@(shared) ofProperty:@"shared"];
    if (shared)
    {
        NSNotificationCenter *nc = [[[self controller] packageController] notificationCenter];
        assert(nc);
        [nc postNotificationForSharingManagedObject:self];
    }
}
- (BOOL)isShared { return [[self getValueOfProperty:@"shared"] boolValue]; }
- (void)shareWithError:(NSError *__autoreleasing *)err
{
    MPContributor *me = [[self.controller.db.packageController contributorsController] me];
    
    if (![self.creator.document.documentID isEqualToString:me.document.documentID])
    {
        if (err)
            *err = [NSError errorWithDomain:MPManagedObjectErrorDomain
                                       code:MPManagedObjectErrorCodeUserNotCreator
                                   userInfo:@{NSLocalizedDescriptionKey :
            [NSString stringWithFormat:@"%@ != %@", self.creator.document.documentID, me.document.documentID] }];
        return;
    }
    assert(!self.isShared);
    [self setShared:YES];
}

- (void)setModerationState:(MPManagedObjectModerationState)moderationState
{
    [self setValue:@(moderationState) ofProperty:@"moderationState"];
}
- (MPManagedObjectModerationState)moderationState
{
    return [[self getValueOfProperty:@"moderationState"] intValue];
}

- (BOOL)moderated { return self.moderationState != MPManagedObjectModerationStateUnmoderated; }
- (BOOL)accepted { return self.moderationState == MPManagedObjectModerationStateAccepted; }
- (BOOL)rejected { return self.moderationState == MPManagedObjectModerationStateRejected; }

- (void)accept
{
    assert(self.moderationState != MPManagedObjectModerationStateAccepted);
    [self setModerationState:MPManagedObjectModerationStateAccepted];
}
- (void)reject
{
    assert(self.moderationState != MPManagedObjectModerationStateRejected);
    [self setModerationState:MPManagedObjectModerationStateRejected];
}

- (NSString *)prototypeID
{
    return [self getValueOfProperty:@"prototypeID"];
}

- (void)setPrototypeID:(NSString *)prototypeID
{
    assert(!self.prototypeID || [prototypeID isEqualToString:prototypeID]); // should be set only once
    [self setValue:prototypeID ofProperty:@"prototypeID"];
}

- (MPManagedObject *)prototype
{
    return [self.controller prototypeForObject:self];
}

- (BOOL)hasPrototype
{
    return self.prototypeID != nil;
}

- (BOOL)canFormPrototype
{
    return YES;
}

- (BOOL)formsPrototypeWhenShared
{
    return NO; // overload in subclasses to form a prototype when shared
}

- (void)refreshCachedValues
{
    
}

// this + property declaration in CouchModel (PrivateExtensions) are there to make the compiler happy.
- (NSMutableSet *)changedNames
{
    return [super changedNames];
}

- (id)prototypeTransformedValueForPropertiesDictionaryKey:(NSString *)key forCopyManagedByController:(MPManagedObjectsController *)cc
{
    return [self getValueOfProperty:key];
}

- (NSString *)humanReadableNameForPropertyKey:(NSString *)key
{
    return [key capitalizedString];
}

- (void)setObjectIdentifierSetValueForManagedObjectArray:(NSArray *)objectArray property:(NSString *)propertyKey
{
    [self setObjectIdentifierArrayValueForManagedObjectArray:[NSSet setWithArray:objectArray] property:propertyKey];
}

- (NSSet *)getValueOfObjectIdentifierSetProperty:(NSString *)propertyKey
{
    return [NSSet setWithArray:[self getValueOfObjectIdentifierArrayProperty:propertyKey]];
}

- (void)setObjectIdentifierArrayValueForManagedObjectArray:(NSArray *)objectArray property:(NSString *)propertyKey
{
#ifdef DEBUG
    for (id o in objectArray) { assert([o isKindOfClass:[MPManagedObject class]]); }
#endif
    NSArray *ids = [objectArray mapObjectsUsingBlock:^id(MPManagedObject *o, NSUInteger idx) {
        NSString *docID = [[o document] documentID]; assert(docID);
        return docID;
    }];
    [self setValue:ids ofProperty:propertyKey];
}

- (NSArray *)getValueOfObjectIdentifierArrayProperty:(NSString *)propertyKey
{
    NSArray *ids = [self getValueOfProperty:propertyKey];
    if (!ids) return @[];
    if (ids.count == 0) return @[];
    
    NSString *str = [[[ids firstObject] componentsSeparatedByString:@":"] firstObject];
    Class moClass = NSClassFromString(str);
    assert(moClass);
    assert([moClass isSubclassOfClass:[MPManagedObject class]]);
    
    // determine if all objects are of the same MO subclass.
    __block BOOL allSameClass = YES;
    [ids enumerateObjectsUsingBlock:^(NSString *objID, NSUInteger idx, BOOL *stop) {
        NSString *classStr = [[objID componentsSeparatedByString:@":"] firstObject];
        assert(classStr);
        Class class = NSClassFromString(str);
        if (class != moClass) { *stop = YES; allSameClass = NO; }
    }];
    
    NSMutableArray *objs = [NSMutableArray arrayWithCapacity:ids.count];
    [ids enumerateObjectsUsingBlock:^(NSString *objID, NSUInteger idx, BOOL *stop) {
        Class cls = [[self class] managedObjectClassFromDocumentID:objID];
        assert(cls);
        MPManagedObjectsController *moc = [self.controller.packageController controllerForManagedObjectClass:cls];
        MPManagedObject *mo = [moc objectWithIdentifier:objID];
        
        if (!mo)
        {
            NSLog(@"WARNING! Could not find object with ID '%@' from '%@'",
                  objID, moc.db.database.URL);
        }
        else
        {
            [objs addObject:mo];            
        }
    }];
    
    return [objs copy];
}

- (void)setDictionaryEmbeddedValue:(id)value forKey:(NSString *)embeddedKey ofProperty:(NSString *)dictPropertyKey
{
    NSMutableDictionary *dict = [self getValueOfProperty:dictPropertyKey];
    id obj = [dict objectForKey:embeddedKey];
    if ([obj isEqual:value]) return; // value unchanged.
    
    assert([dict isKindOfClass:[NSMutableDictionary class]]);
    
    if (!dict)
        [self setValue:[NSMutableDictionary dictionaryWithCapacity:16] ofProperty:dictPropertyKey];
    
    [dict setValue:value forKey:embeddedKey];
    [self cacheValue:dict ofProperty:dictPropertyKey changed:YES];
    [self markNeedsSave];
}

- (id)getValueForDictionaryEmbeddedKey:(NSString *)embeddedKey ofProperty:(NSString *)dictPropertyKey
{
    NSMutableDictionary *dict = [self getValueOfProperty:dictPropertyKey];
    if (dict) assert([dict isKindOfClass:[NSMutableDictionary class]]);
    return dict[embeddedKey];
}

- (CouchDatabase *)databaseForModelProperty:(NSString *)propertyName
{
    Class cls = [[self class] classOfProperty:propertyName];
    assert([cls isSubclassOfClass:[MPManagedObject class]]);
    
    CouchDatabase *db = [self.controller.packageController controllerForManagedObjectClass:cls].db.database;
    if (db) return db;
    
    if (!db) assert([cls conformsToProtocol:@protocol(MPReferencableObject)]);
    
    MPShoeboxPackageController *spkg = [MPShoeboxPackageController sharedShoeboxController];
    db = [spkg controllerForManagedObjectClass:cls].db.database;
    assert(db);
    
    return db;
}

// FIXME: call super once CouchModel's -getModelProperty: is fixed so it doesn't return an empty object.
- (CouchModel *)getModelProperty:(NSString *)property
{
    NSString *objectID = [self getValueOfProperty:property];
    if (!objectID) return nil;
    
    Class cls = [[self class] classOfProperty:property];
    assert([cls isSubclassOfClass:[MPManagedObject class]]);
    
    CouchDatabase *db = [self databaseForModelProperty:property];
    MPDatabasePackageController *pkgc = [db packageController];
    MPManagedObjectsController *moc = [pkgc controllerForManagedObjectClass:cls];
    
    if ([cls conformsToProtocol:@protocol(MPReferencableObject)])
    {
        
        MPManagedObject *mo = [moc objectWithIdentifier:objectID];
        if (mo) return mo;
        
        MPShoeboxPackageController *shoebox = [MPShoeboxPackageController sharedShoeboxController];
        MPManagedObjectsController *sharedMOC = [shoebox controllerForManagedObjectClass:cls];
        
        return [sharedMOC objectWithIdentifier:objectID];
    }
    else
    {
        return [moc objectWithIdentifier:objectID];
    }
    
    assert(false);
    return nil;
}

#pragma mark -

+ (NSArray *)indexablePropertyKeys { return nil; }

- (NSString *)indexableStringForPropertyKey:(NSString *)propertyKey
{
    return [self valueForKey:propertyKey];
}

- (NSString *)tokenizedFullTextString
{
    NSArray *propertyKeys = [[self class] indexablePropertyKeys];
    
    if (propertyKeys.count == 0) return nil;
    
    NSUInteger propertyKeyCount = propertyKeys.count;
    
    NSUInteger capacity = 0;
    for (NSString *key in propertyKeys)
        capacity += [[self valueForKey:key] length] + 1;
        
    NSMutableString *str = [NSMutableString stringWithCapacity:capacity];
    
    NSUInteger i = 0;
    for (NSString *key in propertyKeys)
    {
        NSString *appendedStr = [[self indexableStringForPropertyKey:key] fullTextNormalizedString];
        
        if (appendedStr)
        {
            [str appendString:appendedStr];
            if (i < (propertyKeyCount - 1)) [str appendString:@" "];
        }
        
        i++;
    }
    
    return [str copy];
}

#pragma mark - Embedded object support

- (id)externalizePropertyValue:(id)value
{
    if ([value isKindOfClass:[MPEmbeddedObject class]])
    {
        return [value externalize];
    }
    else if ([value isKindOfClass:[NSArray class]])
    {
        // if no objects in the array are MPEmbeddedObject instances, just return value as is.
        if (![value firstObjectMatching:^BOOL(id evaluatedObject) {
            return [evaluatedObject isKindOfClass:[MPEmbeddedObject class]];
        }]) return value;
        
        NSMutableArray *externalizedArray = [NSMutableArray arrayWithCapacity:[value count]];
        
        for (id obj in value)
        {
            if ([obj isKindOfClass:[MPEmbeddedObject class]])
            {
                if (!externalizedArray)
                    externalizedArray = [NSMutableArray arrayWithCapacity:[obj count]];
                
                [externalizedArray addObject:[obj externalize]];
            }
            else
            {
                [externalizedArray addObject:obj];
            }
        }
        
        return [externalizedArray copy];
    }
    else if ([value isKindOfClass:[NSDictionary class]])
    {
        // if no objects in the dictionary are MPEmbeddedObject instances, just return value as is.
        if (![value anyObjectMatching:^BOOL(id evaluatedKey, id evaluatedObject) {
            return [evaluatedObject isKindOfClass:[MPEmbeddedObject class]];
        }]) return value;
        
        NSMutableDictionary *externalizedDictionary = [NSMutableDictionary dictionaryWithCapacity:[value count]];
        
        for (id key in [value allKeys])
        {
            id obj = value[key];
            if ([obj isKindOfClass:[MPEmbeddedObject class]])
            {
                externalizedDictionary[key] = [obj externalize];
            }
            else
            {
                if (externalizedDictionary) externalizedDictionary[key] = obj;
            }
        }
        
        return [externalizedDictionary copy];
    }
    else
    {
        return [super externalizePropertyValue:value];
    }
    
    assert(false);
    return nil;
}

- (void)setEmbeddedObject:(MPEmbeddedObject *)embeddedObj ofProperty:(NSString *)property
{
    [self cacheEmbeddedObjectByIdentifier:embeddedObj];
    
    assert(!embeddedObj.embeddingKey
           || [embeddedObj.embeddingKey isEqualToString:property]);
    
    assert(!embeddedObj
           ||[embeddedObj isKindOfClass:[MPEmbeddedObject class]]);
    
    embeddedObj.embeddingKey = property;
    [self setValue:embeddedObj ofProperty:property];
}

- (MPEmbeddedObject *)decodeEmbeddedObject:(id)rawValue embeddingKey:(NSString *)key
{
    if ([rawValue isKindOfClass:[NSString class]])
    {
        MPEmbeddedObject *obj = [MPEmbeddedObject embeddedObjectWithJSONString:rawValue embeddingObject:self embeddingKey:key];
        [self cacheEmbeddedObjectByIdentifier:obj];
        return obj;
    }
    else if ([rawValue isKindOfClass:[NSDictionary class]])
    {
        MPEmbeddedObject *obj = [MPEmbeddedObject embeddedObjectWithDictionary:rawValue embeddingObject:self embeddingKey:key];
        [self cacheEmbeddedObjectByIdentifier:obj];
        return obj;
    }
    
    else return nil;
}

- (MPEmbeddedObject *)getEmbeddedObjectProperty:(NSString *)property
{
    id value = [self.properties objectForKey:property];
    if (!value)
    {
        id rawValue = [self.document propertyForKey:property];
        
        if ([rawValue isKindOfClass:[NSString class]]
            || [rawValue isKindOfClass:[NSDictionary class]])
        {
            value = [self decodeEmbeddedObject:rawValue embeddingKey:property];
        }
        else if ([rawValue isKindOfClass:[MPEmbeddedObject class]])
        {
            value = rawValue;
        }
        else if (rawValue)
        {
            MPLog(@"Unable to decode embedded object from property %@ of %@", property, self.document);
            return nil;
        }

        assert(!value
               || [value isKindOfClass:[MPEmbeddedObject class]]);
        
        if (value)
            [self cacheValue:value ofProperty:property changed:NO];
    }
    
    // can be a NSDictionary or NSString still here because
    // -setValuesForPropertiesWithDictionary:(NSDictionary *)keyedValues
    // is not embedded type aware and value externalization can save a string.
    // TODO: consider better implementation.
    else if ([value isKindOfClass:[NSString class]]
             || [value isKindOfClass:[NSDictionary class]])
    {
        value = [self decodeEmbeddedObject:value embeddingKey:property];
        [self cacheValue:value ofProperty:property changed:NO];
    }
    assert(!value
           || [value isKindOfClass:[MPEmbeddedObject class]]);
    
    return value;
}

+ (IMP)impForSetterOfProperty:(NSString*)property ofClass:(Class)propertyClass
{
    if ([propertyClass isSubclassOfClass:[MPEmbeddedObject class]])
    {
        return imp_implementationWithBlock(^(MPManagedObject* receiver, MPEmbeddedObject* value)
        {
            [receiver setEmbeddedObject:value ofProperty:property];
        });
    }
    else if ([propertyClass isSubclassOfClass:[NSArray class]] && [property hasPrefix:@"embedded"])
    {
        return imp_implementationWithBlock(^(MPManagedObject *receiver, NSArray *value)
        {
            NSMutableArray *embeddedObjs = [NSMutableArray arrayWithCapacity:value.count];
            for (__strong id val in value)
            {
                if ([val isKindOfClass:[NSString class]])
                {
                    val = [MPEmbeddedObject embeddedObjectWithJSONString:val embeddingObject:receiver embeddingKey:property];
                }
                else if ([val isKindOfClass:[NSDictionary class]])
                {
                    val = [MPEmbeddedObject embeddedObjectWithDictionary:val embeddingObject:receiver embeddingKey:property];
                }
                else
                {
                    assert([val isKindOfClass:[MPEmbeddedObject class]]);
                }
                
                [receiver cacheEmbeddedObjectByIdentifier:val];
                [embeddedObjs addObject:val];
            }
            
            //TODO: remove contents of previous array of embedded objects from embeddedObjectCache
            [receiver setValue:[embeddedObjs copy] ofProperty:property];
        });
    }
    else if ([propertyClass isSubclassOfClass:[NSDictionary class]] && [property hasPrefix:@"embedded"])
    {
        return imp_implementationWithBlock(^(MPManagedObject *receiver, NSDictionary *value)
        {
            NSMutableDictionary *embeddedObjs = [NSMutableDictionary dictionaryWithCapacity:[value count]];
            for (id key in value)
            {
                id val = value[key];
                
                if ([val isKindOfClass:[NSString class]])
                {
                    val = [MPEmbeddedObject embeddedObjectWithJSONString:val embeddingObject:receiver embeddingKey:property];
                }
                else if ([val isKindOfClass:[NSDictionary class]])
                {
                    val = [MPEmbeddedObject embeddedObjectWithDictionary:value embeddingObject:receiver embeddingKey:property];
                }
                else
                {
                    assert([val isKindOfClass:[MPEmbeddedObject class]]);
                }
                
                //TODO: remove contents of previous dictionary of embedded objects from embeddedObjectCache
                [receiver cacheEmbeddedObjectByIdentifier:val];
                embeddedObjs[key] = val;
            }
            
            [receiver setValue:[embeddedObjs copy] ofProperty:property];
        });
    }
    else
    {
        return [super impForSetterOfProperty: property ofClass: propertyClass];
    }
}

+ (IMP)impForGetterOfProperty:(NSString *)property ofClass:(Class)propertyClass
{
    if ([propertyClass isSubclassOfClass:[MPEmbeddedObject class]])
    {
        return imp_implementationWithBlock(^id(MPManagedObject *receiver) {
            return [receiver getEmbeddedObjectProperty:property];
        });
    }
    else if ([propertyClass isSubclassOfClass:[NSArray class]] && [property hasPrefix:@"embedded"])
    {
        return imp_implementationWithBlock(^NSArray *(MPManagedObject *receiver) {
            NSArray *objs = [receiver getValueOfProperty:property];            
            NSMutableArray *embeddedObjs = [NSMutableArray arrayWithCapacity:10];
            for (id obj in objs)
            {
                MPEmbeddedObject *emb = nil;
                if ([obj isKindOfClass:[NSString class]])
                {
                    emb = [MPEmbeddedObject embeddedObjectWithJSONString:obj embeddingObject:receiver embeddingKey:property];
                }
                else if ([obj isKindOfClass:[NSDictionary class]])
                {
                    emb = [MPEmbeddedObject embeddedObjectWithJSONString:obj embeddingObject:receiver embeddingKey:property];
                }
                else if ([obj isKindOfClass:[MPEmbeddedObject class]])
                {
                    emb = obj;
                }
                [embeddedObjs addObject:emb];
            }
            
            return embeddedObjs;
        });
    }
    else if ([propertyClass isSubclassOfClass:[NSDictionary class]] && [property hasPrefix:@"embedded"])
    {
        return imp_implementationWithBlock(^NSDictionary *(MPManagedObject *receiver) {
            NSDictionary *objs = [receiver getValueOfProperty:property];
            NSMutableDictionary *embeddedObjs = [NSMutableDictionary dictionaryWithCapacity:10];
            for (id key in objs.allKeys)
            {
                id obj = objs[key];
                
                MPEmbeddedObject *emb = nil;
                if ([obj isKindOfClass:[NSString class]])
                {
                    emb = [MPEmbeddedObject embeddedObjectWithJSONString:obj embeddingObject:receiver embeddingKey:property];
                }
                else if ([obj isKindOfClass:[NSDictionary class]])
                {
                    emb = [MPEmbeddedObject embeddedObjectWithDictionary:obj embeddingObject:receiver embeddingKey:property];
                }
                else if ([obj isKindOfClass:[MPEmbeddedObject class]])
                {
                    emb = obj;
                }
                
                embeddedObjs[key] = emb;
            }
            
            return embeddedObjs;
        });
    }
    
    return [super impForGetterOfProperty:property ofClass:propertyClass];
}

#pragma mark - NSPasteboardWriting & NSPasteboardReading

+ (NSString *)pasteboardTypeName
{
    return @"com.piipari.mo.plist";
}

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return @[ [[self class] pasteboardTypeName] ];
}

- (id)pasteboardPropertyListForType:(NSString *)type
{
    NSString *errorStr = nil;
    assert([type isEqualToString:[[self class] pasteboardTypeName]]);
    NSData *dataRep = [NSPropertyListSerialization dataFromPropertyList:self.document.userProperties
                                                                 format:NSPropertyListXMLFormat_v1_0
                                                       errorDescription:&errorStr];
    if (!dataRep && errorStr)
    {
        NSLog(@"ERROR! Could not paste section %@ to pasteboard: %@", self, errorStr);
    }
    
    return dataRep;
}

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return @[ [[self class] pasteboardTypeName] ];
}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard
{
    assert([type isEqualToString:[[self class] pasteboardTypeName]]);
    return NSPasteboardReadingAsPropertyList;
}

@end

@implementation MPManagedObject (Protected)

- (instancetype)initWithNewDocumentForController:(MPManagedObjectsController *)controller
                                      properties:(NSDictionary *)properties
                                      documentID:(NSString *)identifier
{
    assert(controller);
    assert(controller.db);
    assert(controller.db.database);
    
    _controller = controller;
    _newDocumentID = identifier;
    
    if (self = [super initWithNewDocumentInDatabase:controller.db.database])
    {
        assert(_controller);
        [self didInitialize];
        self.isNewObject = YES;
        
        Class moClass = [properties managedObjectType] ? NSClassFromString([properties managedObjectType]) : [self class];
        assert(moClass == [_controller managedObjectClass] ||
               [moClass isSubclassOfClass:[_controller managedObjectClass]]);
        self.objectType = [properties managedObjectType];
        
        [_controller registerObject:self];

        
        NSMutableDictionary *p = properties ? [properties mutableCopy] : [NSMutableDictionary dictionaryWithCapacity:10];
        [p removeObjectForKey:@"_id"];
        [p removeObjectForKey:@"_rev"];
        [p setObject:NSStringFromClass(moClass) forKey:@"objectType"];
        [self setValuesForPropertiesWithDictionary:p];
        
        if (identifier)
            assert([self.document.documentID isEqualToString:identifier]);
        
#if MP_DEBUG_ZOMBIE_MODELS
        assert(![_modelObjectByIdentifierMap objectForKey:self.document.documentID] ||
               ([_modelObjectByIdentifierMap objectForKey:self.document.documentID] == self));
        [_modelObjectByIdentifierMap setObject:self forKey:self.document.documentID];
#endif
    }
    else
    {
        return nil;
    }
    
    return self;
}

- (void)setObjectType:(NSString *)objectType
{
    [self setValue:objectType ofProperty:@"objectType"];
}

- (NSString *)objectType
{
    return [self getValueOfProperty:@"objectType"];
}

- (void)setController:(MPManagedObjectsController *)controller
{
    _controller = controller;
}

@end


#pragma mark - CouchModel additions

@implementation CouchModel (PrivateExtensions)

- (void)setDocument:(CouchDocument *)document { _document = document; }
- (CouchDocument *)document { return _document; }

- (NSMutableDictionary *)properties { return _properties; }
- (NSMutableSet *)changedNames { return _changedNames; }

- (void)markNeedsNoSave
{
    // Note: do NOT set needsSave = false on object itself here.
    // That's MPManagedObject & CouchModel responsibility.
    
    for (NSString *key in self.class.embeddedProperties)
        [[self valueForKey:key] markNeedsNoSave];
}

@end
