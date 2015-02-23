//
//  MPManagedObject.m
//  Feather
//
//  Created by Matias Piipari on 16/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Feather/MPManagedObject+Protected.h>
#import <Feather/NSString+MPExtensions.h>

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
#import "NSNotificationCenter+ErrorNotification.h"

#import "NSString+MPSearchIndex.h"

#import "Mixin.h"
#import "MPCacheableMixin.h"

#import "RegexKitLite.h"

#import <CouchbaseLite/CouchbaseLite.h>

#import <objc/runtime.h>
#import <objc/message.h>

NSString * const MPManagedObjectErrorDomain = @"MPManagedObjectErrorDomain";

NSString *const MPPasteboardTypeManagedObjectFull = @"com.piipari.mo.id.plist";
NSString *const MPPasteboardTypeManagedObjectID = @"com.piipari.mo.id.plist";
NSString *const MPPasteboardTypeManagedObjectIDArray = @"com.piipari.mo.array.plist";

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

@property (readwrite) NSString *sessionID;

@end

@implementation MPReferencableObjectMixin
@end


@implementation MPManagedObject

@synthesize isNewObject = _isNewObject;
@synthesize controller = _controller;
@synthesize embeddedObjectCache = _embeddedObjectCache;
@synthesize deletedDocumentID = _deletedDocumentID;

@dynamic isModerated, isRejected, isAccepted, creator, prototype, sessionID;

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
- (instancetype)initWithNewDocumentInDatabase:(CBLDatabase *)database
{
    if (![self.class isConcrete])
        @throw [NSException exceptionWithName:@"MPAbstractClassException" reason:nil userInfo:nil];
    
    assert(false);
    @throw [NSException exceptionWithName:@"MTInvalidInitException" reason:nil userInfo:nil];
    return nil;
}

- (instancetype)initWithDocument:(CBLDocument *)document
{
    if (![self.class isConcrete])
        @throw [NSException exceptionWithName:@"MPAbstractClassException" reason:nil userInfo:nil];
    
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

- (instancetype)initWithNewDocumentForController:(MPManagedObjectsController *)controller {
    return [self initWithNewDocumentForController:controller properties:nil documentID:nil];
}

- (instancetype)initWithNewDocumentForController:(MPManagedObjectsController *)controller properties:(NSDictionary *)properties {
    return [self initWithNewDocumentForController:controller properties:properties documentID:nil];
}

- (instancetype)initCopyOfManagedObject:(MPManagedObject *)managedObject
                             controller:(MPManagedObjectsController *)controller {
    NSParameterAssert(managedObject);
    NSParameterAssert([managedObject isKindOfClass:self.class]);
    NSParameterAssert(controller);
    
    // drop _id, _rev, _attachments
    NSDictionary *props = [managedObject.propertiesToSave dictionaryWithObjectsMatching:^BOOL(id evaluatedKey, id evaluatedObject) {
        return ![evaluatedKey hasPrefix:@"_"];
    }];
    
    self = [self initWithNewDocumentForController:controller properties:props];
    return self;
}

- (void)didInitialize
{
    _embeddedObjectCache = [NSMutableDictionary dictionaryWithCapacity:20];
    
    assert(_controller);
    if (self.document)
        [_controller registerObject:self];
}

+ (BOOL)hasMainThreadIsolatedCachedProperties {
    return NO;
}

+ (BOOL)shouldTrackSessionID
{
    return NO;
}

- (void)cacheEmbeddedObjectByIdentifier:(MPEmbeddedObject *)obj
{
    assert(obj);
    
    if (!obj)
        return;
    
    assert([obj isKindOfClass:[MPEmbeddedObject class]]);
    assert([obj identifier]); //has non-null identifier
    
    if (_embeddedObjectCache[[obj identifier]])
    {
        assert(_embeddedObjectCache[obj.identifier] == obj);
        return;
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

- (BOOL)isDeleted
{
    return (self.document == nil);
}

+ (NSString *)idForNewDocumentInDatabase:(CBLDatabase *)db
{
    return [NSString stringWithFormat:@"%@:%@", NSStringFromClass([self class]), [[NSUUID UUID] UUIDString]];
}

+ (BOOL)validateRevision:(CBLRevision *)revision {
    return YES;
}

+ (BOOL)requiresProperty:(NSString *)property {
    return NO;
}

+ (Class)managedObjectClassFromDocumentID:(NSString *)documentID
{
    NSParameterAssert(documentID);
    NSParameterAssert([documentID isKindOfClass:[NSString class]]);
    NSAssert(documentID.length >= 10, @"documentID should be of at least 10 characters long: %@", documentID);
    NSString *className = [documentID componentsSeparatedByString:@":"][0];
    Class moClass = NSClassFromString(className);
    assert(moClass);
    assert([moClass isSubclassOfClass:[MPManagedObject class]]);
    return moClass;
}

+ (NSString *)canonicalizedIdentifierStringForString:(NSString *)string {
    /* The JavaScript original:
    function canonicalizeIdentifier(cslIdentifier) {
        return cslIdentifier
        .replace("http://", "")
        .replace(/\//g, "-")
                 .replace(/\./g, "-")
                 .replace(' ', '-')
                 .replace(':', '-');
                 }
    */
    
    // TODO: replace with a more sensible implementation.
    return [[[[[[string stringByReplacingOccurrencesOfString:@"http://" withString:@""]
        stringByReplacingOccurrencesOfString:@"https://" withString:@""]
            stringByReplacingOccurrencesOfString:@"/" withString:@"-"]
                stringByReplacingOccurrencesOfString:@"." withString:@"-"]
                    stringByReplacingOccurrencesOfString:@" " withString:@"-"]
                         stringByReplacingOccurrencesOfString:@":" withString:@"-"];
}

+ (NSString *)humanReadableName
{
    NSString *className = NSStringFromClass(self);
    return [[className componentsMatchedByRegex:@"MP(.*)" capture:1] firstObject];
}

- (NSString *)idForNewDocumentInDatabase:(CBLDatabase *)db {
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

- (void)setControllerWithDocument:(CBLDocument *)document {
    NSString *classStr = [document propertyForKey:@"objectType"];
    assert(classStr);
    Class class = NSClassFromString(classStr);
    
    MPDatabasePackageController *packageController = [document.database packageController];
    MPManagedObjectsController *moc = [packageController controllerForManagedObjectClass:class];
    assert(moc);
    
    assert(!_controller);
    self.controller = moc;
}

- (void)updateTimestamps {
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

+ (BOOL)saveModels:(NSArray *)models error:(NSError *__autoreleasing *)outError {
    MPManagedObjectsController *moc = [[models firstObject] controller];
    for (MPManagedObject *mo in models)
    {
        assert([mo isKindOfClass:[MPManagedObject class]]);
        assert(mo.controller == moc);
        
        if (!mo.document.modelObject)
            mo.document.modelObject = mo;
        
        [mo updateTimestamps];
    }
    
    __block BOOL success = NO;
    mp_dispatch_sync(moc.db.database.manager.dispatchQueue, [moc.packageController serverQueueToken], ^{
        success = [super saveModels:models error:outError];
    });
    
    return success;
}

- (BOOL)save {
    NSError *err = nil;
    BOOL success;
    if (!(success = [self save:&err])) {
#ifdef DEBUG
        NSAssert(false, @"Encountered an error when saving: %@", err);
#endif
        MPDatabasePackageController *pkgc = [self.database packageController];
        [pkgc.notificationCenter postErrorNotification:err];
        return NO;
    }
    
    return success;
}

+ (BOOL)saveModels:(NSArray *)models {
    if (!models || models.count == 0)
        return YES;
    
    MPManagedObject *mo = models[0];
    
    for (MPManagedObject *o in models)
    {
        assert([o isKindOfClass:mo.class]);
        assert(o.controller == mo.controller);
        assert([o isKindOfClass:self]);
    }
    
    BOOL success;
    NSError *err = nil;
    if (!(success = [mo.class saveModels:models error:&err]))
        [[mo.database.packageController notificationCenter] postErrorNotification:err];
    
    return success;
}

- (BOOL)save:(NSError *__autoreleasing *)outError {
    NSParameterAssert(_controller);
    NSParameterAssert(self.document);
    [_controller willSaveObject:self];
    
    assert(self.document.modelObject);
    if (!self.document.modelObject)
        self.document.modelObject = self;
    
    [self updateTimestamps];
    
    if ([self.class shouldTrackSessionID])
        self.sessionID = [[self.controller packageController] sessionID];
    
    __block BOOL success = NO;
    
    mp_dispatch_sync(self.database.manager.dispatchQueue, [self.database.packageController serverQueueToken], ^{
        success = [super save:outError];
    });
    
    if (success) {
        for (NSString *propertyKey in self.class.embeddedProperties) {
            MPEmbeddedObject *embeddedObj = [self valueForKey:propertyKey];
            assert(!embeddedObj
                   || [embeddedObj isKindOfClass:MPEmbeddedObject.class]);
            [embeddedObj setNeedsSave:false];
        }
    }
    
    if (success)
        [self saveCompleted];
    
    return success;
}

- (void)saveCompleted {
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

- (BOOL)deleteDocument {
    __block BOOL success = YES;
    mp_dispatch_sync(self.database.manager.dispatchQueue, [self.controller.packageController serverQueueToken], ^{
        NSError *outError = nil;
        if (!(success = [self deleteDocument:&outError]))
        {
            [[self.database.packageController notificationCenter] postErrorNotification:outError];
            success = NO;
        }
    });
    return success;
}

- (BOOL)deleteDocument:(NSError **)error {
    __block BOOL success = NO;
    
    
    mp_dispatch_sync(self.database.manager.dispatchQueue, [self.database.packageController serverQueueToken], ^{
        CBLSavedRevision* rev = self.document.currentRevision;
        if (!rev) {
            success = YES;
            return;
        }
        
        success = [self _deleteDocument:error];
    });
    
    return success;
}

- (BOOL)_deleteDocument:(NSError *__autoreleasing *)outError {
    assert(_controller);
    
    NSString *deletedDocumentID = self.document.documentID;
    assert(deletedDocumentID);
    
    BOOL success;
    if ((success = [super deleteDocument:outError]))
    {
        _deletedDocumentID = deletedDocumentID;
        
        [_controller didDeleteObject:self];
        
#if MP_DEBUG_ZOMBIE_MODELS
        NSString *docID = self.document.documentID;
        
        if (docID)
            [_modelObjectByIdentifierMap removeObjectForKey:docID];
#endif
    }
    
    return success;
}

- (void)document:(CBLDocument *)doc
          didChange:(CBLDatabaseChange *)change {
    [super document:doc didChange:change];
    
    // TODO: confirm that responses to external changes are not broken by ignoring local changes here.
    if (!change.source)
        return;
    
    assert(doc == self.document);
    
    [_controller didChangeDocument:doc forObject:self source:
     [change.source.scheme isEqualTo:@"cbl"]
        ? MPManagedObjectChangeSourceInternal
        : MPManagedObjectChangeSourceInternal];
}

- (void)didLoadFromDocument {
    //NSLog(@"Did load");
    __block NSError *err = nil;
    __block NSArray *conflictingRevs = nil;
    mp_dispatch_sync(self.database.manager.dispatchQueue, [self.database.packageController serverQueueToken], ^{
        conflictingRevs = [self.document getConflictingRevisions:&err];
    });
    
    if (!conflictingRevs && err)
    {
        [[self.controller.packageController notificationCenter] postErrorNotification:err];
    }
    
    if (conflictingRevs.count > 1)
    {
        NSLog(@"Conflicting revisions: %@", conflictingRevs);
        NSError *err = nil;
        if (![_controller resolveConflictingRevisionsForObject:self error:&err])
        {
            [self.controller.packageController postErrorNotification:err];
        }
    }
    assert(_controller);
    [super didLoadFromDocument]; // super class implementation ought to be empty but just for safety.
    [_controller didLoadObjectFromDocument:self];
}

- (MPManagedObjectsController *)controller {
    return _controller;
}


- (void)setDocument:(CBLDocument *)document {
    if (!_controller)
        [self setControllerWithDocument:document];
    
    [super setDocument:document];
    assert(document.modelObject == self);
    
    if (self.document)
    {
        assert(_controller);
        [_controller registerObject:self];
    }
}

- (BOOL)createAttachmentWithName:(NSString *)name
                      withString:(NSString *)string
                            type:(NSString *)type
                           error:(NSError **)err {
    if (!type)
    {
        if (err)
            *err = [NSError errorWithDomain:MPManagedObjectErrorDomain
                                       code:MPManagedObjectErrorCodeTypeMissing
                                   userInfo:@{NSLocalizedDescriptionKey:
                    [NSString stringWithFormat:@"No type was given for creating attachment from string '%@'", string]}];
        
        return NO;
    }
    
    NSData *body = [string dataUsingEncoding:NSUTF8StringEncoding];
    [self setAttachmentNamed:name withContentType:type content:body];
    
    return YES;
}

- (BOOL)createAttachmentWithName:(NSString*)name
               withContentsOfURL:(NSURL *)url
                            type:(NSString *)type
                           error:(NSError **)err {
    if (!type && [url isFileURL])
    {
        if (![[NSFileManager defaultManager] mimeTypeForFileAtURL:url error:err])
            return NO;
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
        return NO;
    }
    
    NSData *body = [NSData dataWithContentsOfURL:url options:0 error:err];
    if (!body)
        return NO;
    
    [self setAttachmentNamed:name withContentType:type content:body];
    return YES;
}

+ (BOOL)isConcrete
{
    return self.subclasses.count == 0;
}

#pragma mark - Accessors

- (NSDictionary *)propertiesToSave
{
    __block NSDictionary *dict = nil;
    mp_dispatch_sync(self.database.manager.dispatchQueue,
                     [self.database.packageController serverQueueToken], ^{
        dict = [super propertiesToSave];
    });
    
    return dict;
}

- (NSString *)description
{
    __block NSString *desc = nil;
    mp_dispatch_sync(self.database.manager.dispatchQueue, [self.database.packageController serverQueueToken], ^{
        desc = [NSString stringWithFormat:@"[%@, rev:%@]", self.document.documentID, self.document.currentRevisionID];
    });
    return desc;
}

- (void)setCreatedAt:(NSDate *)createdAt {
    assert(createdAt); [self setValue:@([createdAt timeIntervalSince1970]) ofProperty:@"createdAt"];
}

- (NSDate *)createdAt
{
    id createdAtVal = [self getValueOfProperty:@"createdAt"];
    if (!createdAtVal)
        return nil;
    
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

- (void)setEditors:(NSArray *)editors {
    return [self setObjectIdentifierArrayValueForManagedObjectArray:editors property:@"editorIDs"];
}

- (NSArray *)editors {
    return [self getValueOfObjectIdentifierArrayProperty:@"editorIDs"];
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

- (BOOL)isShared {
    return [[self getValueOfProperty:@"shared"] boolValue];
}

- (BOOL)shareWithError:(NSError *__autoreleasing *)err
{
    MPContributor *me = [[self.controller.db.packageController contributorsController] me];
    
    if (![self.creator.document.documentID isEqualToString:me.document.documentID])
    {
        if (err)
            *err = [NSError errorWithDomain:MPManagedObjectErrorDomain
                                       code:MPManagedObjectErrorCodeUserNotCreator
                                   userInfo:@{NSLocalizedDescriptionKey :
            [NSString stringWithFormat:@"%@ != %@", self.creator.document.documentID, me.document.documentID] }];
        return NO;
    }
    assert(!self.isShared);
    [self setShared:YES];
    
    return YES;
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
    return [self getValueOfProperty:@"prototype"];
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
    [self setObjectIdentifierArrayValueForManagedObjectArray:objectArray property:propertyKey];
}

- (NSSet *)getValueOfObjectIdentifierSetProperty:(NSString *)propertyKey
{
    return [NSSet setWithArray:[self getValueOfObjectIdentifierArrayProperty:propertyKey]];
}

- (void)setObjectIdentifierArrayValueForManagedObjectArray:(NSArray *)objectArray property:(NSString *)propertyKey
{
#ifdef DEBUG
    for (id o in objectArray) {
        NSParameterAssert([o isKindOfClass:[MPManagedObject class]]);
    }
#endif
    NSArray *ids = [objectArray mapObjectsUsingBlock:^id(MPManagedObject *o, NSUInteger idx) {
        NSString *docID = [[o document] documentID]; NSParameterAssert(docID);
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
                  objID, moc.db.database.internalURL);
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
    id obj = dict[embeddedKey];
    if ([obj isEqual:value])
        return; // value unchanged.
    
    assert([dict isKindOfClass:[NSMutableDictionary class]]);
    
    if (!dict)
        [self setValue:[NSMutableDictionary dictionaryWithCapacity:16]
            ofProperty:dictPropertyKey];
    
    [dict setValue:value forKey:embeddedKey];
    [self cacheValue:dict ofProperty:dictPropertyKey changed:YES];
    [self markNeedsSave];
}

- (id)getValueForDictionaryEmbeddedKey:(NSString *)embeddedKey ofProperty:(NSString *)dictPropertyKey
{
    NSMutableDictionary *dict = [self getValueOfProperty:dictPropertyKey];
    if (dict)
        NSParameterAssert([dict isKindOfClass:[NSMutableDictionary class]]);
    return dict[embeddedKey];
}

- (CBLDatabase *)databaseForModelProperty:(NSString *)propertyName
{
    Class cls = [self.class classOfProperty:propertyName];
    NSParameterAssert([cls isSubclassOfClass:[MPManagedObject class]]);
    
    CBLDatabase *db = [self.controller.packageController controllerForManagedObjectClass:cls].db.database;
    if (db)
        return db;
    
    if (!db)
        NSParameterAssert([cls conformsToProtocol:@protocol(MPReferencableObject)]);
    
    MPShoeboxPackageController *spkg = [MPShoeboxPackageController sharedShoeboxController];
    db = [spkg controllerForManagedObjectClass:cls].db.database;
    NSParameterAssert(db);
    
    return db;
}

// FIXME: call super once CouchModel's -getModelProperty: is fixed so it doesn't return an empty object.
- (CBLModel *)getModelProperty:(NSString *)property
{
    NSString *objectID = [self getValueOfProperty:property];
    if (!objectID)
        return nil;
    
    Class cls = [[self class] classOfProperty:property];
    assert([cls isSubclassOfClass:[MPManagedObject class]]);
    
    MPManagedObjectsController *moc = nil;
    
    if ([cls isConcrete])
    {
        CBLDatabase *db = [self databaseForModelProperty:property];
        MPDatabasePackageController *pkgc = [db packageController];
        moc = [pkgc controllerForManagedObjectClass:cls];
        assert(moc);
    }
    else
    {
        NSArray *components = [objectID componentsSeparatedByString:@":"];
        assert(components.count == 2);
        Class concreteClass = NSClassFromString(components[0]);
        assert(concreteClass);
        assert([concreteClass isSubclassOfClass:cls]);
        moc = [self.controller.packageController controllerForManagedObjectClass:concreteClass];
        assert(moc);
        cls = concreteClass;
    }
    
    if ([cls conformsToProtocol:@protocol(MPReferencableObject)])
    {
        
        MPManagedObject *mo = [moc objectWithIdentifier:objectID];
        if (mo)
            return mo;
        
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

#pragma mark - Singular and plural strings

+ (NSString *)singular {
    return [[NSStringFromClass(self) stringByReplacingOccurrencesOfRegex:@"^MP" withString:@""] camelCasedString];
}

+ (NSString *)plural {
    return [[self singular] pluralizedString];
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

+ (IMP)impForSetterOfProperty:(NSString*)property ofClass:(Class)propertyClass
{
    if ([propertyClass isSubclassOfClass:[MPEmbeddedObject class]]) {
        return imp_implementationWithBlock(^(MPManagedObject* receiver, MPEmbeddedObject* value) {
            [receiver setEmbeddedObject:value ofProperty:property];
        });
    }
    else if ([propertyClass isSubclassOfClass:[NSArray class]] && [property hasPrefix:@"embedded"]) {
        return imp_implementationWithBlock(^(MPManagedObject *receiver, NSArray *value) {
            [receiver setEmbeddedObjectArray:value ofProperty:property];
        });
    }
    else if ([propertyClass isSubclassOfClass:[NSDictionary class]] && [property hasPrefix:@"embedded"]) {
        return imp_implementationWithBlock(^(MPManagedObject *receiver, NSDictionary *value) {
            [receiver setEmbeddedObjectDictionary:value ofProperty:property];
        });
    }
    else {
        return [super impForSetterOfProperty: property ofClass: propertyClass];
    }
}

+ (IMP)impForGetterOfProperty:(NSString *)property ofClass:(Class)propertyClass
{
    if ([propertyClass isSubclassOfClass:[MPEmbeddedObject class]]) {
        return imp_implementationWithBlock(^id(MPManagedObject *receiver) {
            return [receiver getEmbeddedObjectProperty:property];
        });
    }
    else if ([propertyClass isSubclassOfClass:[NSArray class]] && [property hasPrefix:@"embedded"]) {
        return imp_implementationWithBlock(^NSArray *(MPManagedObject *receiver) {
            return [receiver getEmbeddedObjectArrayProperty:property];
        });
    }
    else if ([propertyClass isSubclassOfClass:[NSDictionary class]] && [property hasPrefix:@"embedded"]) {
        return imp_implementationWithBlock(^NSDictionary *(MPManagedObject *receiver) {
            return [receiver getEmbeddedObjectDictionaryProperty:property];
        });
    }
    
    return [super impForGetterOfProperty:property ofClass:propertyClass];
}

#pragma mark - NSPasteboardWriting & NSPasteboardReading

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    
    return @[ MPPasteboardTypeManagedObjectFull,
              MPPasteboardTypeManagedObjectID,
              MPPasteboardTypeManagedObjectIDArray ];
}

- (NSDictionary *)referableDictionaryRepresentation
{
    return @{
      @"_id":self.documentID,
      @"objectType" : self.objectType,
      @"databasePackageID" : ((MPDatabasePackageController *)(self.controller.packageController)).fullyQualifiedIdentifier
    };
}

- (id)pasteboardPropertyListForType:(NSString *)type
{
    // Only these two types should be called directly on MPManagedObject instances (ObjectID array type is for a collection of objects)
    assert([type isEqual:MPPasteboardTypeManagedObjectFull]
           || [type isEqual:MPPasteboardTypeManagedObjectID]);
    
    NSString *errorStr = nil;
    NSData *dataRep = nil;
    if ([type isEqual:MPPasteboardTypeManagedObjectFull])
    {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:self.propertiesToSave];
        dict[@"databasePackageID"] = ((MPDatabasePackageController *)(self.controller.packageController)).fullyQualifiedIdentifier;
        
        assert([type isEqualToString:MPPasteboardTypeManagedObjectFull]);
        dataRep = [NSPropertyListSerialization dataFromPropertyList:dict
                                                             format:NSPropertyListXMLFormat_v1_0
                                                   errorDescription:&errorStr];
    }
    else if ([type isEqual:MPPasteboardTypeManagedObjectID])
    {
        dataRep = [NSPropertyListSerialization dataFromPropertyList:self.referableDictionaryRepresentation
                                                             format:NSPropertyListXMLFormat_v1_0
                                                   errorDescription:&errorStr];
    }
    
    if (!dataRep && errorStr)
    {
        NSLog(@"ERROR! Could not paste object %@ to pasteboard: %@", self, errorStr);
    }
    
    return dataRep;
}

+ (NSData *)pasteboardObjectIDPropertyListForObjects:(NSArray *)objects error:(NSError **)err
{
    NSArray *objectIDDicts = [objects mapObjectsUsingBlock:^id(MPManagedObject *mo, NSUInteger idx) {
        NSDictionary *dict = [mo referableDictionaryRepresentation];
        assert([NSPropertyListSerialization propertyList:dict isValidForFormat:NSPropertyListXMLFormat_v1_0]);
        return dict;
    }];
    
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:objectIDDicts format:NSPropertyListXMLFormat_v1_0 options:0 error:err];
    return data;
}

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return @[ MPPasteboardTypeManagedObjectFull,
              MPPasteboardTypeManagedObjectID ];
}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard
{
    assert([type isEqualToString:MPPasteboardTypeManagedObjectFull]
           || [type isEqualToString:MPPasteboardTypeManagedObjectID]);
    return NSPasteboardReadingAsPropertyList;
}

- (id)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type
{
    NSParameterAssert([type isEqualToString:MPPasteboardTypeManagedObjectFull]
                      || [type isEqualToString:MPPasteboardTypeManagedObjectID]);

    id obj = [self initWithPasteboardObjectIDPropertyList:propertyList ofType:MPPasteboardTypeManagedObjectID];
    if ([type isEqual:MPPasteboardTypeManagedObjectFull] && obj)
            [obj setValuesForPropertiesWithDictionary:propertyList];
    
    return obj;
}

- (id)initWithPasteboardObjectIDPropertyList:(id)propertyList ofType:(NSString *)type
{
    NSParameterAssert([type isEqual:MPPasteboardTypeManagedObjectID]);
    NSParameterAssert(self.class == NSClassFromString([propertyList managedObjectType]));
    NSParameterAssert([propertyList isKindOfClass:[NSDictionary class]]);
    
    return [self.class objectWithReferableDictionaryRepresentation:propertyList];
}


+ (id)objectWithReferableDictionaryRepresentation:(NSDictionary *)referableDictionaryRep
{
    NSString *objectTypeStr = [referableDictionaryRep objectForKey:@"objectType"];
    Class objectType = NSClassFromString(objectTypeStr);
    assert(objectType);
    
    NSString *packageControllerID = [referableDictionaryRep objectForKey:@"databasePackageID"];
    MPDatabasePackageController *pkgc = [MPDatabasePackageController databasePackageControllerWithFullyQualifiedIdentifier:packageControllerID];
    assert(pkgc);
    
    MPManagedObjectsController *moc = [pkgc controllerForManagedObjectClass:objectType];
    assert(moc);
    
    NSString *objectID = [referableDictionaryRep managedObjectDocumentID];
    
    id obj = [moc objectWithIdentifier:objectID];
    assert(obj);
    
    return obj;
}

#pragma mark -

- (NSDictionary *)JSONEncodableDictionaryRepresentation
{
    NSDictionary *props = self.propertiesToSave;
    return [props dictionaryWithObjectsMatching:^BOOL(id evaluatedKey, id evaluatedObject) {
        return ![evaluatedKey isEqualToString:@"_attachments"];
    }];
}

- (NSString *)JSONStringRepresentation:(NSError **)err
{
    NSDictionary *props = self.JSONEncodableDictionaryRepresentation;
    assert(props);
    
    NSData *data = [CBLJSON dataWithJSONObject:props options:NSJSONWritingPrettyPrinted error:err];

    if (!data)
        return nil;
    
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return str;
}



#pragma mark - Scripting support

+ (NSString *)objectSpecifierKey {
    NSString *specKey = [@"all" stringByAppendingString:
                         [[NSStringFromClass(self.class) stringByReplacingOccurrencesOfRegex:@"^MP"
                                                                                  withString:@""] pluralizedString]];
    return specKey;
}

- (NSString *)objectSpecifierKey
{
    return self.class.objectSpecifierKey;
}

- (NSScriptObjectSpecifier *)objectSpecifier
{
    assert(self.documentID);
    assert(self.controller);
    NSScriptObjectSpecifier *containerRef = self.controller.objectSpecifier;
    assert(containerRef);
    //assert(containerRef.keyClassDescription);
    
    NSScriptClassDescription *classDesc = [NSScriptClassDescription classDescriptionForClass:self.controller.class];
    return [[NSUniqueIDSpecifier alloc] initWithContainerClassDescription:classDesc containerSpecifier:containerRef
                                                                      key:self.objectSpecifierKey uniqueID:self.documentID];
}

- (NSDictionary *)scriptingProperties
{
    NSArray *keys = [self.propertiesToSave allKeys];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:keys.count];
    
    for (__strong id k in keys) {
        if ([k hasPrefix:@"_"])
            continue;
        
        if ([k hasSuffix:@"IDs"])
            k = [k stringByReplacingOccurrencesOfRegex:@"IDs$" withString:@"s"];
        
        if ([k hasSuffix:@"ID"])
            k = [k stringByReplacingOccurrencesOfRegex:@"ID$" withString:@""];
        
        id v = [self valueForKey:k];
        
        if (![v objectSpecifier])
            continue;
        
        dict[k] = v;
    }
    
    dict[@"documentID"] = self.documentID;
    
    return dict.copy;
}

- (void)setScriptingProperties:(NSDictionary *)scriptingProperties {
    for (id k in scriptingProperties)
        [self setValue:scriptingProperties[k] ofProperty:k];
}

- (id)saveWithCommand:(NSScriptCommand *)command {
    return  @([self save]);
}

- (NSString *)pluralizedElementKeyForObject:(id)o
{
    Class cls = nil;
    NSString *key = nil;
    SEL keySel = nil;
    do {
        cls = cls ? cls.superclass : [[[o firstObject] objectsByEvaluatingSpecifier] class];
        if (cls == NSObject.class)
            return nil;
        
        key = cls.plural;
        keySel = NSSelectorFromString(key);
        
        NSLog(@"%@: %@ -> %@ (%hhd)", self, o, key, [self respondsToSelector:keySel]);
    }
    while (![self respondsToSelector:keySel]);
    
    return key;
}

- (id)addWithCommand:(NSScriptCommand *)command {
    [command evaluatedArguments];
    
    id targetObj = [command evaluatedReceivers];
    NSParameterAssert(targetObj == self);
    
    id addedObj = command.evaluatedArguments[@"Object"];
                   
    if ([addedObj isKindOfClass:NSArray.class]) {
        NSString *key = [targetObj pluralizedElementKeyForObject:addedObj];
        NSAssert(key, @"No pluralized element name was found for inserting object %@ into %@", addedObj, self);
        
        NSUInteger insertionPoint = [[targetObj valueForKey:key] count];
        NSUInteger i = insertionPoint;
        
        for (id oSpec in addedObj) {
            id o = [oSpec objectsByEvaluatingSpecifier];
            [targetObj insertValue:o atIndex:i++ inPropertyWithKey:key];
        }
    } else {
        id addedO = [addedObj objectsByEvaluatingSpecifier];
        NSString *key = [[addedO class] plural];
        NSUInteger insertionPoint = [[targetObj valueForKey:key] count];
        
        [targetObj insertValue:addedO atIndex:insertionPoint inPropertyWithKey:key];
    }
    
    [targetObj save];
    
    return targetObj;
}

- (void)setScriptingDerivedProperties:(NSDictionary *)properties
{
    for (id key in properties) {
        id v = properties[key];
        if ([v isKindOfClass:NSScriptObjectSpecifier.class]) {
            id evObjs = [v objectsByEvaluatingSpecifier];
            [self setValue:evObjs forKey:key];
        }
        else {
            [self setValue:properties[key] forKey:key];
        }
    }
}


@end

@implementation MPManagedObject (Protected)
@dynamic prototype;

+ (instancetype)modelForDocument:(CBLDocument *)document
{
    assert(document);
    assert(document.database);
    
    if (document.modelObject)
    {
        assert([document.modelObject isKindOfClass:self.class]);
        return (id)document.modelObject;
    }
    
    CBLModel *cm = [super modelForDocument:document];
    assert ([cm isKindOfClass:[MPManagedObject class]]);
    
    MPManagedObject *mo = (MPManagedObject *)cm;
    
    if (!mo.controller)
        [mo setControllerWithDocument:document];
    
    assert(mo.controller);
    assert([document.properties[@"objectType"] isEqualToString:NSStringFromClass(self)]);
    
    return mo;
}

- (instancetype)initWithNewDocumentForController:(MPManagedObjectsController *)controller
                                      properties:(NSDictionary *)properties
                                      documentID:(NSString *)identifier
{
    if (![self.class isConcrete])
        @throw [NSException exceptionWithName:@"MPAbstractClassException" reason:nil userInfo:nil];
    
    assert(controller);
    assert(controller.db);
    assert(controller.db.database);
    
    _controller = controller;
    _newDocumentID = identifier;
    
    self = [super initWithNewDocumentInDatabase:controller.db.database];
    NSParameterAssert(self.document);
    
    if (self)
    {
        assert(_controller);
        [self didInitialize];
        self.isNewObject = YES;
        
        Class moClass = [properties managedObjectType] ? NSClassFromString([properties managedObjectType]) : [self class];
        assert(moClass == [_controller managedObjectClass] ||
               [moClass isSubclassOfClass:[_controller managedObjectClass]]);
        
        if (properties && properties.managedObjectType)
        {
            assert([properties.managedObjectType isEqualToString:NSStringFromClass(moClass)]);
            self.objectType = properties.managedObjectType;
        }
        
        [_controller registerObject:self];
        
        NSMutableDictionary *p = properties ? [properties mutableCopy] : [NSMutableDictionary dictionaryWithCapacity:10];
        [p removeObjectForKey:@"_id"];
        [p removeObjectForKey:@"_rev"];
        p[@"objectType"] = NSStringFromClass(moClass);
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
    assert(objectType);
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

- (void)setValue:(id)value ofProperty:(NSString *)property
{
    #ifdef DEBUG
    if ([property isEqualToString:@"objectType"])
        assert(value);
    #endif
    
    // should not be setting objectType to nil.
    if ([property isEqualTo:@"objectType"])
    {
        NSString *existingObjectType = [self getValueOfProperty:@"objectType"];
        assert(value);
        
        if (existingObjectType)
        {
            if (![value isEqual:existingObjectType])
                @throw [NSException exceptionWithName:@"MPInvalidArgumentException" reason:@"Trying to reset objectType" userInfo:nil];
            
            return; // nothing to do (value is the same)
        }
    }
    
    // should not be setting _id to nil
    if ([property isEqual:@"_id"])
    {
        assert(value);
        
        NSString *existingID = [self getValueOfProperty:@"_id"];
        
        if (existingID)
        {
            if (![value isEqual:existingID])
                @throw [NSException exceptionWithName:@"MPInvalidArgumentException" reason:@"Trying to reset _id" userInfo:nil];
            
            return; // nothing to do (value is the same)
        }
    }
    
    NSParameterAssert(self.document);
    [super setValue:value ofProperty:property];
}

- (void)setEmbeddedObject:(MPEmbeddedObject *)embeddedObj ofProperty:(NSString *)property
{
    [self cacheEmbeddedObjectByIdentifier:embeddedObj];
    
    assert(!embeddedObj.embeddingKey
           || [embeddedObj.embeddingKey isEqualToString:property]);
    
    assert(!embeddedObj
           ||[embeddedObj isKindOfClass:[MPEmbeddedObject class]]);
    
    if (embeddedObj.embeddingKey)
        assert([embeddedObj.embeddingKey isEqualToString:property]);
    
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
    else
    {
        return nil;
    }
}

- (MPEmbeddedObject *)getEmbeddedObjectProperty:(NSString *)property
{
    id value = [self getUnsavedValueOfProperty:property];
    
    if (!value)
    {
        __block id rawValue = nil;
        mp_dispatch_sync(self.database.manager.dispatchQueue, [self.controller.packageController serverQueueToken], ^{
            rawValue = [self.document propertyForKey:property];
        });
        
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

- (void)setEmbeddedObjectArray:(NSArray *)value ofProperty:(NSString *)property {
    NSMutableArray *embeddedObjs = [NSMutableArray arrayWithCapacity:value.count];
    for (__strong id val in value) {
        if ([val isKindOfClass:[NSString class]]) {
            val = [MPEmbeddedObject embeddedObjectWithJSONString:val embeddingObject:self embeddingKey:property];
        }
        else if ([val isKindOfClass:[NSDictionary class]]) {
            val = [MPEmbeddedObject embeddedObjectWithDictionary:val embeddingObject:self embeddingKey:property];
        }
        else {
            assert([val isKindOfClass:[MPEmbeddedObject class]]);
        }
        
        [self cacheEmbeddedObjectByIdentifier:val];
        [embeddedObjs addObject:val];
    }
    
    //TODO: remove contents of previous array of embedded objects from embeddedObjectCache
    [self setValue:[embeddedObjs copy] ofProperty:property];
}

- (NSArray *)getEmbeddedObjectArrayProperty:(NSString *)property {
    NSArray *objs = [self getValueOfProperty:property];
    NSMutableArray *embeddedObjs = [NSMutableArray arrayWithCapacity:10];
    for (id obj in objs)
    {
        MPEmbeddedObject *emb = nil;
        if ([obj isKindOfClass:[NSString class]])
        {
            emb = [MPEmbeddedObject embeddedObjectWithJSONString:obj embeddingObject:self embeddingKey:property];
        }
        else if ([obj isKindOfClass:[NSDictionary class]])
        {
            emb = [MPEmbeddedObject embeddedObjectWithDictionary:obj embeddingObject:self embeddingKey:property];
        }
        else if ([obj isKindOfClass:[MPEmbeddedObject class]])
        {
            emb = obj;
        }
        else {
            @throw [[MPUnexpectedStateExpection alloc] initWithReason:[NSString stringWithFormat:@"Object of unexpected type: %@", obj]];
            return nil;
        }
        
        if (emb)
            [embeddedObjs addObject:emb];
    }
    
    return embeddedObjs;
}

- (NSDictionary *)getEmbeddedObjectDictionaryProperty:(NSString *)property {
    NSDictionary *objs = [self getValueOfProperty:property];
    NSMutableDictionary *embeddedObjs = [NSMutableDictionary dictionaryWithCapacity:10];
    for (id key in objs.allKeys)
    {
        id obj = objs[key];
        MPEmbeddedObject *emb = nil;
        if ([obj isKindOfClass:[NSString class]]) {
            emb = [MPEmbeddedObject embeddedObjectWithJSONString:obj embeddingObject:self embeddingKey:property];
        }
        else if ([obj isKindOfClass:[NSDictionary class]]) {
            emb = [MPEmbeddedObject embeddedObjectWithDictionary:obj embeddingObject:self embeddingKey:property];
        }
        else if ([obj isKindOfClass:[MPEmbeddedObject class]]) {
            emb = obj;
        }
        else {
            @throw [[MPUnexpectedStateExpection alloc] initWithReason:
                        [NSString stringWithFormat:@"Object of unexpected type: %@", obj]];
            return nil;
        }
        
        embeddedObjs[key] = emb;
    }
    
    return embeddedObjs;
}

- (void)setEmbeddedObjectDictionary:(NSDictionary *)value ofProperty:(NSString *)property {
    NSMutableDictionary *embeddedObjs = [NSMutableDictionary dictionaryWithCapacity:[value count]];
    for (id key in value)
    {
        id val = value[key];
        
        if ([val isKindOfClass:[NSString class]]) {
            val = [MPEmbeddedObject embeddedObjectWithJSONString:val embeddingObject:self embeddingKey:property];
        }
        else if ([val isKindOfClass:[NSDictionary class]]) {
            val = [MPEmbeddedObject embeddedObjectWithDictionary:value embeddingObject:self embeddingKey:property];
        }
        else {
            assert([val isKindOfClass:[MPEmbeddedObject class]]);
        }
        
        //TODO: remove contents of previous dictionary of embedded objects from embeddedObjectCache
        [self cacheEmbeddedObjectByIdentifier:val];
        embeddedObjs[key] = val;
    }
    
    [self setValue:[embeddedObjs copy] ofProperty:property];
}


@end


#pragma mark - CouchModel additions

@implementation CBLModel (PrivateExtensions)
@dynamic document;

- (void)markNeedsNoSave
{
    // Note: do NOT set needsSave = false on object itself here.
    // That's MPManagedObject & CouchModel responsibility.
    
    for (NSString *key in self.class.embeddedProperties)
        [[self valueForKey:key] markNeedsNoSave];
}

@end
