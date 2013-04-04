//
//  MPManagedObject.m
//  Feather
//
//  Created by Matias Piipari on 16/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPDatabase.h"
#import "MPManagedObject.h"
#import "MPManagedObjectsController.h"
#import <Feather/MPManagedObject+Protected.h>
#import "MPManagedObjectsController+Protected.h"
#import "MPDatabasePackageController.h"
#import "NSNotificationCenter+MPExtensions.h"
#import "MPShoeboxPackageController.h"

#import "MPEmbeddedObject.h"

#import "NSFileManager+MPExtensions.h"
#import "NSDictionary+MPManagedObjectExtensions.h"
#import "MPEmbeddedObject.h"

#import "NSArray+MPExtensions.h"
#import "NSObject+MPExtensions.h"
#import "MPContributor.h"
#import "MPContributorsController.h"
#import "MPShoeboxPackageController.h"

#import "Mixin.h"
#import "MPCacheableMixin.h"

#import "RegexKitLite.h"
#import <CouchCocoa/CouchCocoa.h>

#import <objc/runtime.h>
#import <objc/message.h>

NSString * const MPManagedObjectErrorDomain = @"MPManagedObjectErrorDomain";

@interface CouchModel (Private)
@property (strong, readwrite) CouchDocument *document;
@property (strong, readwrite) NSMutableDictionary *properties;
@property (copy, readonly) NSString *documentID;
- (void)couchDocumentChanged:(CouchDocument *)doc;
- (id)externalizePropertyValue: (id)value;
@end

@interface MPManagedObject ()
{
    __weak MPManagedObjectsController *_controller;
    NSString *_newDocumentID;
}

@property (readwrite) BOOL isNewObject;
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
    }
}

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
    assert(_controller);
    if (self.document)
        [_controller registerObject:self];
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
    
    CouchModel *cm = [super modelForDocument:document];
    assert ([cm isKindOfClass:[MPManagedObject class]]);

    MPManagedObject *mo = (MPManagedObject *)cm;
    
    if (!mo.controller) [mo setControllerWithDocument:document];
    
    assert(mo.controller);
        
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
    for (id mo in models)
    {
        assert([mo isKindOfClass:[MPManagedObject class]]);
        [mo updateTimestamps];
    }
    return [super saveModels:models];
}

- (RESTOperation *)save
{
    assert(_controller);
    [_controller willSaveObject:self];
    
    [self updateTimestamps];
    
    RESTOperation *oper = [super save];
    
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
    
    RESTOperation *op = [super deleteDocument];
    [op onCompletion:^{
        [_controller didDeleteObject:self];
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

- (BOOL)formsPrototype
{
    return NO; // overload in subclasses to form a prototype when shared
}

- (void)refreshCachedValues
{
    
}

- (id)prototypeTransformedValueForKey:(NSString *)key
{
    return [self humanReadableNameForPropertyKey:key];
}

- (NSString *)humanReadableNameForPropertyKey:(NSString *)key
{
    return [key capitalizedString];
}

- (void)setObjectIdentifierSetValueForManagedObjectArray:(NSArray *)objectArray property:(NSString *)propertyKey
{
    [self setObjectIdentifierArrayValueForManagedObjectArray:[NSSet setWithArray:objectArray] property:propertyKey];
}

- (NSSet *)objectSetOfProperty:(NSString *)propertyKey
{
    return [NSSet setWithArray:[self objectArrayOfProperty:propertyKey]];
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

- (NSArray *)objectArrayOfProperty:(NSString *)propertyKey
{
    NSArray *ids = [self getValueOfProperty:propertyKey];
    if (!ids) return @[];
    if (ids.count == 0) return @[];
    
    NSString *str = [[propertyKey componentsSeparatedByString:@":"] firstObject];
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
    
    // get all objects in one go if they're all of the same MO subclass.
    if (allSameClass)
    {
        CouchQueryEnumerator *qenum = [[self.database getDocumentsWithIDs:ids] rows];
        MPManagedObjectsController *moc = [self.controller.db.packageController controllerForManagedObjectClass:moClass];
        return [moc managedObjectsForQueryEnumerator:qenum];
    }
    
    // get objects separately if they're different classes (potentially different controllers).
    return [ids mapObjectsUsingBlock:^(NSString *sid, NSUInteger idx)
    {
        return [self.controller.db.database getDocumentWithID:sid].modelObject;
    }];
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

#pragma mark - Embedded object support

- (id)externalizePropertyValue:(id)value
{
    if ([value isKindOfClass:[MPEmbeddedObject class]])
    {
        return [value externalize];
    }
    else
    {
        return [super externalizePropertyValue:value];
    }
    
    assert(false);
    return nil;
}

- (NSDate *)getEmbeddedObjectProperty:(NSString *)property
{
    assert(self.properties);
    NSDate* value = [self.properties objectForKey: property];
    if (!value)
    {
        id rawValue = [self.document propertyForKey:property];
        if ([rawValue isKindOfClass: [NSString class]])
            value = [MPEmbeddedObject embeddedObjectWithJSONString:rawValue embeddingObject:self];
        if (value)
            [self cacheValue: value ofProperty: property changed: NO];
        else if (rawValue)
            MPLog(@"Unable to decode embedded object from property %@ of %@", property, self.document);
    }
    return value;
}

+ (IMP)impForGetterOfProperty:(NSString *)property ofClass:(Class)propertyClass
{
    if ([propertyClass isSubclassOfClass:[MPEmbeddedObject class]])
    {
        return imp_implementationWithBlock(^id(MPManagedObject *receiver) {
            return [receiver getEmbeddedObjectProperty:property];
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

- (instancetype)initWithNewDocumentForController:(MPManagedObjectsController *)controller properties:(NSDictionary *)properties documentID:(NSString *)identifier
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