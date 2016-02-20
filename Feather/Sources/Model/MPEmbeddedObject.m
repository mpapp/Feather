//
//  MPEmbeddedObject.m
//  Feather
//
//  Created by Matias Piipari on 03/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPEmbeddedObject.h"
#import "MPException.h"
#import "MPManagedObject.h"
#import "MPManagedObject+Protected.h"
#import "MPEmbeddedObject+Protected.h"
#import "MPEmbeddedPropertyContainingMixin.h"
#import "NSNotificationCenter+ErrorNotification.h"
@import FeatherExtensions;

#import "MPDeepSaver.h"

#import "Mixin.h"

@import CouchbaseLite;
@import ObjectiveC;

NSString *const MPPasteboardTypeEmbeddedObjectFull    = @"com.piipari.eo.full.plist";
NSString *const MPPasteboardTypeEmbeddedObjectID      = @"com.piipari.eo.id.plist";
NSString *const MPPasteboardTypeEmbeddedObjectIDArray = @"com.piipari.eo.id.array.plist";

@interface MPEmbeddedObject ()
{
    NSString *_embeddingKey;
}
@property (readwrite, strong) NSMutableDictionary *embeddedObjectCache;
@end

@implementation MPEmbeddedObject
@synthesize embeddingObject = _embeddingObject;
@synthesize embeddedObjectCache = _embeddedObjectCache;
@synthesize properties = _properties;
@synthesize needsSave = _needsSave;
@synthesize changedNames = _changedNames;

#ifdef DEBUG

+ (NSMutableSet *)embeddedObjectIDs
{
    static NSMutableSet *embeddedObjectIDs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        embeddedObjectIDs = [NSMutableSet set];
    });
    
    return embeddedObjectIDs;
}

#endif

+ (void)initialize
{
    if (self == [MPEmbeddedObject class])
    {
        [self mixinFrom:[MPEmbeddedPropertyContainingMixin class] followInheritance:NO force:NO];
    }
}

- (instancetype)init
{
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

- (instancetype)initWithJSONString:(NSString *)jsonString
                   embeddingObject:(id<MPEmbeddingObject>)embeddingObject
                      embeddingKey:(NSString *)key
{
    NSError *err = nil;
    NSDictionary *propertiesDict = [NSJSONSerialization JSONObjectWithData:
                                    [jsonString dataUsingEncoding:NSUTF8StringEncoding]
                                                                   options:0 error:&err];
    if (!propertiesDict) {
        NSLog(@"ERROR! Failed to parse embedded object from string '%@' for object %@ key %@: %@",
              jsonString, embeddingObject, key, err);
    }
    
    return [self initWithDictionary:propertiesDict embeddingObject:embeddingObject embeddingKey:key];
}

- (instancetype)initWithDictionary:(NSDictionary *)propertiesDict
                   embeddingObject:(id<MPEmbeddingObject>)embeddingObject
                      embeddingKey:(NSString *)key
{
    if (self = [super init])
    {
        assert([propertiesDict isKindOfClass:[NSDictionary class]]);
        
        if (propertiesDict[@"_id"]) {
            assert([propertiesDict[@"_id"] hasPrefix:NSStringFromClass(self.class)]);
            assert(propertiesDict[@"objectType"]); // if one of _id or objectType is present, both should be.
        }
        
        if (propertiesDict[@"objectType"]) {
            assert([propertiesDict[@"objectType"] isEqualToString:NSStringFromClass(self.class)]);
            assert(propertiesDict[@"_id"]); // if one of _id or objectType is present, both should be.
        }
        
        assert(key);
        assert(embeddingObject);
        
        _embeddingObject = embeddingObject;
        _embeddingKey = key;
        
        _properties = [propertiesDict mutableCopy];
        
        if (!propertiesDict[@"_id"]) {
            self.identifier = [NSString stringWithFormat:@"%@:%@", NSStringFromClass(self.class), [NSUUID.UUID UUIDString]];
            _properties[@"objectType"] = NSStringFromClass(self.class);
        }
        
        _embeddedObjectCache = [NSMutableDictionary dictionaryWithCapacity:20];

        // thread-safely unique
        @synchronized(embeddingObject) {
            MPEmbeddedObject *obj = [embeddingObject embeddedObjectWithIdentifier:self.identifier];
            if (!obj)
                [embeddingObject cacheEmbeddedObjectByIdentifier:self];
            else
                return obj;
        }
    }
    
    return self;
}

- (instancetype)initWithEmbeddingObject:(id<MPEmbeddingObject>)embeddingObject
                           embeddingKey:(NSString *)embeddingKey
{
    self = [super init];
    if (self) {
        assert(embeddingObject);
        assert(embeddingKey);
        
        _embeddingObject = embeddingObject;
        _embeddingKey = embeddingKey;
        
        _properties = [NSMutableDictionary dictionaryWithCapacity:10];
        _properties[@"_id"] = [NSString stringWithFormat:@"%@:%@",
                               NSStringFromClass([self class]), [[NSUUID UUID] UUIDString]];
        _properties[@"objectType"] = NSStringFromClass([self class]);
        
        _embeddedObjectCache = [NSMutableDictionary dictionaryWithCapacity:20];
        
        // thread-safely unique
        @synchronized(embeddingObject) {
            MPEmbeddedObject *obj = [embeddingObject embeddedObjectWithIdentifier:self.identifier];
            if (!obj)
                [embeddingObject cacheEmbeddedObjectByIdentifier:self];
            else
                return obj;            
        }
    }
    
    return self;
}

+ (instancetype)embeddedObjectWithJSONString:(NSString *)string
                             embeddingObject:(id<MPEmbeddingObject>)embeddingObject
                                embeddingKey:(NSString *)key
{
    if (!string)
        return nil;
    
    Class cls = nil;

    NSError *err = nil;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding]
                                                               options:0 error:&err];
    if (!dictionary) {
        NSLog(@"Failed to parse embedded object of class %@ from string %@ for object %@ key %@: %@",
              self.class, string, embeddingObject, key, err);
        return nil;
    }

    if (self == [MPEmbeddedObject class])
    {
        cls = dictionary[@"objectType"] ? NSClassFromString(dictionary[@"objectType"]) : nil;
        if (!cls) { MPLog(@"Could not decode an embedded object from:\n%@", string); return nil; }
        assert([cls isSubclassOfClass:[MPEmbeddedObject class]]);
    }
    else
    {
        cls = self;
        assert(cls == NSClassFromString(dictionary[@"objectType"]));
    }

    return [[cls alloc] initWithDictionary:dictionary embeddingObject:embeddingObject embeddingKey:key];
}

+ (instancetype)embeddedObjectWithDictionary:(NSDictionary *)dictionary
                             embeddingObject:(id<MPEmbeddingObject>)embeddingObject
                                embeddingKey:(NSString *)key
{
    Class cls = nil;
    
    if (self == [MPEmbeddedObject class])
    {
        assert([dictionary isKindOfClass:NSDictionary.class]);
        cls = dictionary[@"objectType"] ? NSClassFromString(dictionary[@"objectType"]) : nil;
        if (!cls)
        {
            MPLog(@"Could not decode an embedded object from:\n%@", dictionary);
            return nil;
        }
        assert([cls isSubclassOfClass:[MPEmbeddedObject class]]);
    }
    else
    {
        cls = self;
        assert(cls == NSClassFromString(dictionary[@"objectType"]));
    }
    
    MPEmbeddedObject *existingObj = nil;
    if ((existingObj = [embeddingObject embeddedObjectWithIdentifier:dictionary[@"_id"]]))
        return existingObj;

    return [[cls alloc] initWithDictionary:dictionary embeddingObject:embeddingObject embeddingKey:key];
}

- (MPEmbeddedObject *)embeddedObjectWithIdentifier:(NSString *)identifier
{
    NSAssert(_embeddedObjectCache, @"Embedded object cache is unexpectedly nil");
    return _embeddedObjectCache[identifier];
}

- (void)setEmbeddingKey:(NSString *)embeddingKey
{
    if (embeddingKey && _embeddingKey == embeddingKey)
        return;
    
    // should be set only once to a non-null value (shouldn't try setting to non-null value B after setting to A)
    NSAssert(!_embeddingKey || [_embeddingKey isEqualToString:embeddingKey],
             @"Unexpected _embeddingKey: %@ (expected nil or %@)", _embeddingKey, embeddingKey);
    
    _embeddingKey = embeddingKey;
}

- (NSString *)embeddingKey
{
    return _embeddingKey;
}

#pragma mark -

- (id)getValueOfProperty:(NSString *)property
{
    return _properties[property];
}

- (BOOL)setValue:(id)value ofProperty:(NSString *)property
{
    id val = [self getValueOfProperty:property];
    //if ([val isEqualToValue:value]) return YES;
    if ([val isEqual:value])
        return YES;
    
    NSAssert(property, @"Attempting to set value of property with nil argument for object: %@", self);
    NSAssert(self.embeddingObject, @"Object should have a non-nil embeddingObject: %@", self);
    NSAssert(self.embeddingKey, @"Object should have a non-nil embeddingKey: %@", self);
    NSAssert(_properties, @"Object should have its _properties set when setting value to a property: %@", self);
    
    MPManagedObject *o = ((MPManagedObject *)self.embeddingObject);
    
    if (value) {
        _properties[property] = value;
        _needsSave = true;
    } else {
        [_properties removeObjectForKey:property];
    }
    
    Class cls = [o.class classOfProperty:self.embeddingKey];
    
    BOOL isScalarProperty = ![cls isSubclassOfClass:NSArray.class]
                            && ![cls isSubclassOfClass:NSDictionary.class]
                            && ![cls isSubclassOfClass:NSSet.class];
    if (!isScalarProperty) {
        // if self is in a collection contained by the embeddingObject,
        // -cacheValue:ofProperty:changed: is used to communicate that something inside the collection has changed (requires rewriting the JSON).
        [o cacheValue:[o valueForKey:self.embeddingKey] ofProperty:self.embeddingKey changed:YES];
    }
    else {
        [o cacheValue:self ofProperty:self.embeddingKey changed:YES];
    }
    
    if ([o isKindOfClass:MPManagedObject.class])
        [o markPropertyNeedsSave:self.embeddingKey];
    
    [o markNeedsSave];
    
    return YES;
}

- (MPManagedObject *)embeddingManagedObject {
    id e = self;
    
    while ((e = [e embeddingObject])) {
        if ([e isKindOfClass:MPManagedObject.class])
            return e;
    }
    
    NSLog(@"Failed to recover the embedding managed object for embedded object: %@", self);
    return nil;
}

- (void)setIdentifier:(NSString *)identifier
{
    _properties[@"_id"] = identifier;
}

- (NSString *)identifier
{
    return _properties[@"_id"];
}

- (void)cacheValue:(id)value ofProperty:(NSString *)property changed:(BOOL)changed {
    NSAssert(property, @"Attempting to set value of property with nil property argument: %@", self);
    NSAssert(self.embeddingObject, @"Object should have a non-nil embeddingObject: %@", self);
    NSAssert(self.embeddingKey, @"Object should have a non-nil embeddingKey: %@", self);
    NSAssert(_properties, @"Object should have its _properties set when setting value to a property: %@", self);
    
    Class cls = [self.embeddingObject.class classOfProperty:self.embeddingKey];
    NSAssert(cls, @" No property declaration for '%@' in class '%@'", property, self.class);

    BOOL isScalarProperty = ![cls isSubclassOfClass:NSArray.class]
                                && ![cls isSubclassOfClass:NSDictionary.class]
                                && ![cls isSubclassOfClass:NSSet.class];
    if (!isScalarProperty) {
        // if self is in a collection contained by the embeddingObject,
        // -cacheValue:ofProperty:changed: is used to communicate that something inside the collection has changed (requires rewriting the JSON).
        [self.embeddingObject cacheValue:[(id)self.embeddingObject valueForKey:self.embeddingKey] ofProperty:self.embeddingKey changed:YES];
    }
    else {
        [self.embeddingObject cacheValue:self ofProperty:self.embeddingKey changed:YES];
    }
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

// Adapted from CouchCocoa's CouchModel
// Transforms cached property values back into JSON-compatible objects
- (id)externalizePropertyValue:(id)value
{
    if ([value isKindOfClass:[NSData class]])
    {
        value = [CBLJSON base64StringWithData:value];
    }
    else if ([value isKindOfClass:[NSDate class]])
    {
        value = [CBLJSON JSONObjectWithDate:value];
    }
    else if ([value isKindOfClass:[CBLModel class]])
    {
        assert([value document]);
        value = [[value document] documentID];
    }
    else if ([value isKindOfClass:[MPEmbeddedObject class]])
    {
        // objects should be unique by their identifier
        [self cacheEmbeddedObjectByIdentifier:value];
        value = [value externalize];
    }
    else if ([value isKindOfClass:[NSArray class]])
    {
        NSMutableArray *externalizedArray = [NSMutableArray arrayWithCapacity:[value count]];
        
        for (id obj in value)
        {
            if ([obj isKindOfClass:[MPEmbeddedObject class]])
            {
                [self cacheEmbeddedObjectByIdentifier:obj];
                [externalizedArray addObject:[obj externalize]];
            }
            else
            {
                if (externalizedArray)
                [externalizedArray addObject:obj];
            }
        }
        
        return [externalizedArray copy];
    }
    else if ([value isKindOfClass:[NSDictionary class]])
    {
        NSMutableDictionary *externalizedDictionary = [NSMutableDictionary dictionaryWithCapacity:[value count]];
        
        for (id key in [value allKeys])
        {
            id obj = value[key];
            if ([obj isKindOfClass:[MPEmbeddedObject class]])
            {
                [self cacheEmbeddedObjectByIdentifier:obj];
                externalizedDictionary[key] = [obj externalize];
            }
            else
            {
                if (externalizedDictionary)
                    externalizedDictionary[key] = obj;
            }
        }
        
        return [externalizedDictionary copy];
    }
    
    return value;
}

- (NSDictionary *)dictionaryRepresentation
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:self.properties.count];
    
    for (id key in _properties)
        dict[key] = [self externalizePropertyValue:_properties[key]];

    return dict;
}

- (id)externalize
{
    return self.dictionaryRepresentation;
}

- (BOOL)save:(NSError **)err
{
    if (self.identifier) {
        NSAssert([[self.identifier componentsSeparatedByString:@":"].firstObject isEqualToString:NSStringFromClass(self.class)],
                 @"Unexpected identifier for object of class %@", self.class);
    }
    
    return [_embeddingObject save:err];
}

- (BOOL)save
{
    NSError *err = nil;
    BOOL success;
    if (!(success = [self save:&err]))
    {
        [[NSNotificationCenter defaultCenter] postErrorNotification:err];
        return NO;
    }
    
    return success;
}

- (BOOL)deepSave {
    NSError *err = nil;
    BOOL success;
    if (!(success = [self deepSave:&err])) {
#ifdef DEBUG
        NSAssert(false, @"Encountered an error when saving: %@", err);
#endif
        id embeddingO = self;
        while ((embeddingO = [embeddingO embeddingObject])) {
            if ([embeddingO isKindOfClass:MPManagedObject.class])
                break;
        }
        
        MPDatabasePackageController *pkgc = [[embeddingO database] packageController];
        [pkgc.notificationCenter postErrorNotification:err];
        return NO;
    }
    
    return success;
}


- (BOOL)deepSave:(NSError *__autoreleasing *)outError {
    return [MPDeepSaver deepSave:self error:outError];
}

- (void)markNeedsSave
{
    NSAssert(_embeddingObject, @"Expecting an embedding object for %@ (%@)", self, self.class);
    self.needsSave = true;
    [_embeddingObject markNeedsSave];
}

- (void)markNeedsNoSave
{
    self.needsSave = false;
    
    NSAssert(_embeddingObject, @"Expecting an embedding object for %@ (%@)", self, self.class);
    for (NSString *propertyKey in [self.class embeddedProperties]) {
         [[self valueForKey:propertyKey] markNeedsNoSave];
    }
}

#pragma mark - Accessor implementations

- (CBLDatabase *)databaseForModelProperty:(NSString *)property {
    id<MPEmbeddingObject> embedder = nil;
    while (![(embedder = self.embeddingObject) isKindOfClass:[MPManagedObject class]]) {
        NSAssert(embedder, @"Expecting an embedding object for %@ (%@), %@", self, self.class, self.embeddingObject);
    }
    NSAssert([embedder isKindOfClass:[MPManagedObject class]],
             @"Expecting embedding object to be a managed object: %@ (%@)", embedder, embedder.class);
    
    MPManagedObject *mo = (MPManagedObject *)embedder;
    
    Class cls = [self.class classOfProperty:property];
    
    // try to infer the MOC and via that its database,
    // 1) get the controller for the embedder (first MO encountered when walking 'embeddingObject' relations).
    // 2) failing that get the MOC via shared package controller.
    // either #1 or #2 must succeed.
    MPManagedObjectsController *inferredMOC = [mo.controller.packageController controllerForManagedObjectClass:cls];
    CBLDatabase *inferredDB = inferredMOC
                                ? inferredMOC.db.database
                                : [MPShoeboxPackageController.sharedShoeboxController controllerForManagedObjectClass:cls].db.database;
    NSParameterAssert(inferredDB);
    
    return inferredDB;
}

// adapted from CouchModel
- (CBLModel *)getModelProperty:(NSString *)property
{
    NSString* rawValue = [self getValueOfProperty:property];
    if (!rawValue)
        return nil;
    
    // Look up the CBLDocument:
    if (![rawValue isKindOfClass: [NSString class]]) {
        MPLog(@"Model-valued property %@ of %@ is not a string", property, self);
        return nil;
    }
    
    CBLDatabase *db = [self databaseForModelProperty: property];
    
    __block CBLDocument *doc = nil;
    mp_dispatch_sync(db.manager.dispatchQueue, [[db packageController] serverQueueToken], ^{
        doc = [db existingDocumentWithID:rawValue];
    });
    
    if (!doc)
    {
        Class declaredInClass = nil;
        const char *propertyType;
        if (MYGetPropertyInfo(self.class, property, YES, &declaredInClass, &propertyType)) {
            Class moClass = MYClassFromType(propertyType);
            
            MPManagedObjectsController *moc = [[[(id)self.embeddingObject controller] packageController] controllerForManagedObjectClass:moClass];
            CBLModel *model = [moc objectWithIdentifier:rawValue];
            
            if (model)
                return model;
        }
        
        MPLog(@"Unable to get document from property %@ of %@ (value='%@')",
             property, doc, rawValue);
        return nil;
    }
    
    // Ask factory to get/create model; if it doesn't know, use the declared class:
    CBLModel *value = [doc.database.modelFactory modelForDocument: doc];
    if (!value && ![doc isDeleted])
    {
        Class declaredClass = [[self class] classOfProperty: property];
        value = [declaredClass modelForDocument: doc];
        if (!value)
            MPLog(@"Unable to instantiate %@ from %@ -- property %@ of %@ (%@)",
                 declaredClass, doc, property, self, self);
    }
    return value;
}

- (NSArray *)getEmbeddedObjectArrayProperty:(NSString *)property
{
    NSArray *rawValue = [self getValueOfProperty:property];
    if (!rawValue)
        return nil;
    
    assert([rawValue isKindOfClass:[NSArray class]]);
    
    NSMutableArray *embeddedObjs = [NSMutableArray arrayWithCapacity:rawValue.count];
    for (id rawObj in rawValue) {
        if (![rawObj isKindOfClass:[NSString class]]) {
            MPLog(@"Embedded object array typed valued property %@ of %@ contains object other than string: %@", property, self, rawObj);
            return nil;
        }
        
        NSError *err = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[rawObj dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&err];
        NSString *objType = dict[@"objectType"];
        assert(objType);
        Class cls = NSClassFromString(objType);
        assert(cls);
        
        NSString *identifier = dict[@"_id"];
        assert(identifier);
        
        MPEmbeddedObject *obj = _embeddedObjectCache[identifier];
        
        if (!obj)
        {
            obj = [[cls alloc] initWithDictionary:dict
                                  embeddingObject:self.embeddingObject embeddingKey:property];
            [self cacheEmbeddedObjectByIdentifier:obj];
        }
        
        assert(obj);
        [embeddedObjs addObject:obj];
    }
    
    return embeddedObjs;
}

- (NSDictionary *)getEmbeddedObjectDictionaryProperty:(NSString *)property
{
    NSDictionary *rawValue = [self getValueOfProperty:property];
    if (!rawValue)
        return nil;
    
    assert([rawValue isKindOfClass:[NSDictionary class]]);
    
    NSMutableDictionary *embeddedObjs = [NSMutableDictionary dictionaryWithCapacity:rawValue.count];
    for (id key in rawValue)
    {
        id rawObj = rawValue[key];
        if (![rawObj isKindOfClass:[NSString class]])
        {
            MPLog(@"Embedded object array typed valued property %@ of %@ contains object other than string: %@", property, self, rawObj);
            return nil;
        }
        
        NSError *err = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[rawObj dataUsingEncoding:NSUTF8StringEncoding]
                                                                     options:0 error:&err];
        if (!dict) {
            NSLog(@"ERROR! Failed to parse value for property %@ of object %@: %@",
                  property, self, err);
            return nil;
        }

        NSString *objType = dict[@"objectType"];
        assert(objType);
        Class cls = NSClassFromString(objType);
        assert(cls);
        
        NSString *identifier = dict[@"_id"];
        assert(identifier);
        
        MPEmbeddedObject *obj = _embeddedObjectCache[identifier];
        
        if (!obj)
        {
            obj = [[cls alloc] initWithDictionary:dict
                                  embeddingObject:self.embeddingObject embeddingKey:property];
            [self cacheEmbeddedObjectByIdentifier:obj];
        }
        
        assert(obj);
        embeddedObjs[key] = obj;
    }
    
    return embeddedObjs;
}

- (NSDate *)getDateProperty:(NSString *)property
{
    id value = _properties[property];
    
    if ([value isKindOfClass:[NSString class]]) {
        value = [CBLJSON dateWithJSONObject:value];
    }
    
    if (value && ![value isKindOfClass:[NSDate class]]) {
        MPLog(@"Unable to decode date from property %@ of %@", property, self);
        return nil;
    }
    
    //if (value)
    //    [self cacheValue: value ofProperty: property changed: NO];
    
    
    return value;
}

- (NSData *)getDataProperty:(NSString *)property
{
    id value = _properties[property];
    
    if ([value isKindOfClass:[NSString class]]) {
        value = [CBLJSON dataWithBase64String:value];
    }
    else if (value && ![value isKindOfClass:[NSData class]]) {
        MPLog(@"Unable to decode Base64 data from property %@ of %@", property, self); return nil;
    }
    
    //if (value) // TODO: Cache decoded values.
    //    [self cacheValue:value ofProperty: property changed: NO];
    
    return value;
}


+ (IMP)impForGetterOfProperty:(NSString *)property ofClass:(Class)propertyClass
{
    if (propertyClass == Nil
        || propertyClass == [NSString class]
        || propertyClass == [NSNumber class]
        || propertyClass == [NSArray class]
        || propertyClass == [NSDictionary class])
        return [super impForGetterOfProperty:property ofClass: propertyClass];  // Basic classes (including 'id')
    else if (propertyClass == [NSData class])
    {
        return imp_implementationWithBlock(^id(MPEmbeddedObject *receiver)
        {
            return [receiver getDataProperty: property];
        });
    } else if (propertyClass == [NSDate class])
    {
        return imp_implementationWithBlock(^id(MPEmbeddedObject *receiver)
        {
            return [receiver getDateProperty: property];
        });
    } else if ([propertyClass isSubclassOfClass:[CBLModel class]])
    {
        return imp_implementationWithBlock(^id(MPEmbeddedObject *receiver)
        {
            return [receiver getModelProperty:property];
        });
    } else if ([propertyClass isSubclassOfClass:[NSArray class]] && [property hasPrefix:@"embedded"])
    {
        return imp_implementationWithBlock(^NSArray *(MPEmbeddedObject *receiver)
        {
            return [receiver getEmbeddedObjectArrayProperty:property];
        });
    } else if ([propertyClass isSubclassOfClass:[NSDictionary class]] && [property hasPrefix:@"embedded"])
    {
        return imp_implementationWithBlock(^NSDictionary *(MPEmbeddedObject *receiver)
        {
            return [receiver getEmbeddedObjectDictionaryProperty:property];
        });
    }
    else
    {
        return NULL;  // Unsupported
    }
}

- (void)setModel:(CBLModel *)model
     forProperty:(NSString *)property
{
    if (_properties[property]
        && ([_properties[property] isEqualToString:model.document.documentID]
            ||
            (!_properties[property] && !model))) return;
    
    if (model)
    {
        assert(model.document);
        _properties[property] = model.document.documentID;
    }
    else
    {
        [_properties removeObjectForKey:property];
    }
    
    [self markNeedsSave];
}

+ (IMP)impForSetterOfProperty:(NSString *)property ofClass:(Class)propertyClass
{
    if ([propertyClass isSubclassOfClass:[CBLModel class]])
    {
        return imp_implementationWithBlock(^(MPEmbeddedObject *receiver, CBLModel *value)
        {
            [receiver setModel:value forProperty:property];
        });
    }
    else if ([propertyClass isSubclassOfClass:[MPEmbeddedObject class]])
    {
        return imp_implementationWithBlock(^(MPEmbeddedObject *receiver, MPEmbeddedObject *value)
        {
            if (value)
                [receiver cacheEmbeddedObjectByIdentifier:value];
            else
                [receiver removeEmbeddedObjectFromByIdentifierCache:[receiver valueForKey:property]];
            
            BOOL result = [receiver setValue:value ofProperty:property];
            assert(result);
        });
    }
    else if ([propertyClass isSubclassOfClass:[NSArray class]] && [property hasPrefix:@"embedded"])
    {
        return imp_implementationWithBlock(^(MPEmbeddedObject *receiver, NSArray *value)
        {
            // drop cached values (in case some embedded object references have been dropped.)
            NSArray *existingValues = [receiver valueForKey:property];
            for (MPEmbeddedObject *obj in existingValues)
            {
                [receiver removeEmbeddedObjectFromByIdentifierCache:obj];
            }
            
            // add cached values
            // TODO: adding might re-add some that were just removed before, optimise if that becomes a problem.
            for (MPEmbeddedObject *obj in value)
            {
                [receiver cacheEmbeddedObjectByIdentifier:obj];
            }
            
            BOOL result = [receiver setValue:value ofProperty:property];
            assert(result);
        });
    }
    else if ([propertyClass isSubclassOfClass:[NSDictionary class]] && [property hasPrefix:@"embedded"])
    {
        return imp_implementationWithBlock(^(MPEmbeddedObject *receiver, NSDictionary *value)
        {
            // drop cached values (in case some embedded object references have been dropped.)
            NSDictionary *existingValues = [receiver valueForKey:property];
            for (id key in existingValues)
            {
                [receiver removeEmbeddedObjectFromByIdentifierCache:existingValues[key]];
            }
            
            // add cached values
            // TODO: adding might re-add some that were just removed before, optimise if that becomes problem.
            for (id key in value)
            {
                id obj = value[key];
                [receiver cacheEmbeddedObjectByIdentifier:obj];
            }
            
            BOOL result = [receiver setValue:value ofProperty:property];
            assert(result);
        });
    }
    else
    {
        return [super impForSetterOfProperty:property ofClass:propertyClass];
    }
}

+ (IMP)impForGetterOfProperty:(NSString *)property ofType:(const char *)propertyType
{
    if (propertyType[0] == _C_ULNG_LNG)
    {
        return imp_implementationWithBlock(^unsigned long long(MYDynamicObject *receiver) {
            return [[receiver getValueOfProperty:property] unsignedLongValue];
        });
    }
    else if (propertyType[0] == _C_LNG_LNG)
    {
        return imp_implementationWithBlock(^long long(MYDynamicObject *receiver) {
            return [[receiver getValueOfProperty:property] longLongValue];
        });
    }
    
    return [super impForGetterOfProperty:property ofType:propertyType];
}

+ (IMP)impForSetterOfProperty:(NSString *)property ofType:(const char *)propertyType
{
    if (propertyType[0] == _C_ULNG_LNG)
    {
        return imp_implementationWithBlock(^(MYDynamicObject *receiver, unsigned long long value) {
            [receiver setValue:@(value) ofProperty:property];
        });
    }
    else if (propertyType[0] == _C_LNG_LNG)
    {
        return imp_implementationWithBlock(^(MYDynamicObject *receiver, long long value) {
            [receiver setValue:@(value) ofProperty:property];
        });
    }
    
    return [super impForSetterOfProperty:property ofType:propertyType];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@ %@>", NSStringFromClass(self.class), self.properties];
}

#pragma mark - NSPasteboardWriting & NSPasteboardReading

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return @[ MPPasteboardTypeEmbeddedObjectFull,
              MPPasteboardTypeEmbeddedObjectID,
              MPPasteboardTypeEmbeddedObjectIDArray ];
}

- (NSDictionary *)referableDictionaryRepresentation {
    id embeddingObjectID = [self.embeddingObject isKindOfClass:MPEmbeddedObject.class] ? [(id)self.embeddingObject identifier] : [(id)self.embeddingObject documentID];
    if (!embeddingObjectID) {
        return nil;
    }
    
    id embeddingManagedObjectID = self.embeddingManagedObject.documentID;
    if (!embeddingObjectID) {
        return nil;
    }
    
    return @{
             @"_id"                    : self.identifier,
             @"embeddingObject"        : embeddingObjectID,
             @"embeddingKey"           : self.embeddingKey,
             @"embeddingManagedObject" : embeddingManagedObjectID,
             @"databasePackageID"      : [self.embeddingManagedObject.controller.packageController fullyQualifiedIdentifier]
        };
}

- (id)pasteboardPropertyListForType:(NSString *)type
{
    // Only these two types should be called directly on MPEmbeddedObject instances (ObjectID array type is for a collection of objects)
    NSParameterAssert([type isEqual:MPPasteboardTypeEmbeddedObjectFull]
                      || [type isEqual:MPPasteboardTypeEmbeddedObjectID]
                      || [type isEqual:MPPasteboardTypeEmbeddedObjectIDArray]);
    
    NSError *error = nil;
    NSData *dataRep = nil;
    if ([type isEqual:MPPasteboardTypeEmbeddedObjectFull])
    {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:self.properties];
        
        NSParameterAssert([type isEqualToString:MPPasteboardTypeEmbeddedObjectFull]);
        dataRep = [NSPropertyListSerialization dataWithPropertyList:dict
                                                             format:NSPropertyListXMLFormat_v1_0
                                                            options:0
                                                              error:&error];
    }
    else if ([type isEqual:MPPasteboardTypeEmbeddedObjectID])
    {
        dataRep = [NSPropertyListSerialization dataWithPropertyList:self.referableDictionaryRepresentation
                                                             format:NSPropertyListXMLFormat_v1_0
                                                            options:0
                                                              error:&error];
    }
    else if ([type isEqual:MPPasteboardTypeEmbeddedObjectIDArray] && self.referableDictionaryRepresentation)
    {
        dataRep = [NSPropertyListSerialization dataWithPropertyList:@[self.referableDictionaryRepresentation]
                                                             format:NSPropertyListXMLFormat_v1_0
                                                            options:0
                                                              error:&error];
    }
    
    if (!dataRep && error) {
        NSLog(@"ERROR! Could not paste object %@ to pasteboard: %@", self, error);
    }
    
    return dataRep;
}

+ (NSData *)pasteboardObjectIDPropertyListForObjects:(NSArray *)objects error:(NSError **)err
{
    NSArray *objectIDDicts = [objects mapObjectsUsingBlock:^id(MPEmbeddedObject *mo, NSUInteger idx) {
        NSDictionary *dict = [mo referableDictionaryRepresentation];
        assert([NSPropertyListSerialization propertyList:dict isValidForFormat:NSPropertyListXMLFormat_v1_0]);
        return dict;
    }];
    
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:objectIDDicts format:NSPropertyListXMLFormat_v1_0 options:0 error:err];
    return data;
}

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return @[ MPPasteboardTypeEmbeddedObjectFull,
              MPPasteboardTypeEmbeddedObjectID,
              MPPasteboardTypeEmbeddedObjectIDArray ];
}

+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard
{
    NSParameterAssert([type isEqualToString:MPPasteboardTypeEmbeddedObjectFull]
                      || [type isEqualToString:MPPasteboardTypeEmbeddedObjectID]
                      || [type isEqualToString:MPPasteboardTypeEmbeddedObjectIDArray]);
    return NSPasteboardReadingAsPropertyList;
}

- (id)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type {
    NSParameterAssert([type isEqualToString:MPPasteboardTypeEmbeddedObjectFull]
                      || [type isEqualToString:MPPasteboardTypeEmbeddedObjectID]
                      || [type isEqualToString:MPPasteboardTypeEmbeddedObjectIDArray]);
    
    id obj = [self initWithPasteboardObjectIDPropertyList:propertyList ofType:MPPasteboardTypeEmbeddedObjectID];
    if ([type isEqual:MPPasteboardTypeEmbeddedObjectFull] && obj) {
        [obj setValuesForPropertiesWithDictionary:propertyList];
    }
    
    return obj;
}

- (id)initWithPasteboardObjectIDPropertyList:(id)propertyList ofType:(NSString *)type
{
    NSParameterAssert([type isEqual:MPPasteboardTypeEmbeddedObjectID]);
    NSParameterAssert([propertyList isKindOfClass:[NSDictionary class]]);
    
    return [self.class objectWithReferableDictionaryRepresentation:propertyList];
}

+ (id)objectWithReferableDictionaryRepresentation:(NSDictionary *)referableDictionaryRep
{
    NSString *packageControllerID = referableDictionaryRep[@"databasePackageID"];
    MPDatabasePackageController *pkgc = [MPDatabasePackageController databasePackageControllerWithFullyQualifiedIdentifier:packageControllerID];
    NSParameterAssert(pkgc);
    
    MPManagedObject *mo = [pkgc objectWithIdentifier:referableDictionaryRep[@"embeddingManagedObject"]];
    
    // FIXME: support arbitrary keypaths to get from embeddingManagedObject to the object that was actually put on the pasteboard.
    return [mo valueForKey:referableDictionaryRep[@"embeddingKey"]];
}

#pragma mark - Scripting

- (NSScriptObjectSpecifier *)objectSpecifier
{
    assert(self.embeddingObject);
    
    NSScriptObjectSpecifier *containerRef = [(id)self.embeddingObject objectSpecifier];
    assert(containerRef);
    //assert(containerRef.keyClassDescription);
    
    NSScriptClassDescription *classDesc = [NSScriptClassDescription classDescriptionForClass:self.embeddingObject.class];
    return [[NSPropertySpecifier alloc] initWithContainerClassDescription:classDesc containerSpecifier:containerRef key:self.embeddingKey];
}

@end