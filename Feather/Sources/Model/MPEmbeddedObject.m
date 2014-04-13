//
//  MPEmbeddedObject.m
//  Feather
//
//  Created by Matias Piipari on 03/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPEmbeddedObject.h"
#import "JSONKit.h"
#import "MPException.h"
#import "MPManagedObject.h"
#import "MPManagedObject+Protected.h"
#import "MPEmbeddedObject+Protected.h"
#import "MPEmbeddedPropertyContainingMixin.h"
#import "NSNotificationCenter+ErrorNotification.h"

#import "Mixin.h"

#import <CouchbaseLite/CouchbaseLite.h>

#import <objc/runtime.h>

@interface MPEmbeddedObject ()
{
    NSString *_embeddingKey;
}
@property (readwrite, strong) NSMutableDictionary *embeddedObjectCache;
@end

@implementation MPEmbeddedObject

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
    NSMutableDictionary *propertiesDict = [jsonString objectFromJSONString];
    return [self initWithDictionary:propertiesDict embeddingObject:embeddingObject embeddingKey:key];
}

- (instancetype)initWithDictionary:(NSDictionary *)propertiesDict
                   embeddingObject:(id<MPEmbeddingObject>)embeddingObject
                      embeddingKey:(NSString *)key
{
    if (self = [super init])
    {
        assert([propertiesDict isKindOfClass:[NSDictionary class]]);
        assert(propertiesDict[@"_id"]);
        assert(propertiesDict[@"objectType"]);
        assert([propertiesDict[@"objectType"] isEqualToString:NSStringFromClass(self.class)]);
        assert(key);
        assert(embeddingObject);
        
        _embeddingObject = embeddingObject;
        _embeddingKey = key;
        
        _properties = [propertiesDict mutableCopy];

        _embeddedObjectCache = [NSMutableDictionary dictionaryWithCapacity:20];

        // TODO: make embedded objects thread-safely unique
        MPEmbeddedObject *obj = [embeddingObject embeddedObjectWithIdentifier:self.identifier];
        if (!obj)
            [embeddingObject cacheEmbeddedObjectByIdentifier:self];
        else
            return obj;
    }
    
    return self;
}

- (instancetype)initWithEmbeddingObject:(id<MPEmbeddingObject>)embeddingObject
                           embeddingKey:(NSString *)embeddingKey
{
    if (self = [super init])
    {
        assert(embeddingObject);
        assert(embeddingKey);
        
        _embeddingObject = embeddingObject;
        _embeddingKey = embeddingKey;
        
        _properties = [NSMutableDictionary dictionaryWithCapacity:10];
        _properties[@"_id"] = [NSString stringWithFormat:@"%@:%@",
                               NSStringFromClass([self class]), [[NSUUID UUID] UUIDString]];
        _properties[@"objectType"] = NSStringFromClass([self class]);
        
        _embeddedObjectCache = [NSMutableDictionary dictionaryWithCapacity:20];
        
        // TODO: make embedded objects thread-safely unique
        MPEmbeddedObject *obj = [embeddingObject embeddedObjectWithIdentifier:self.identifier];
        if (!obj)
            [embeddingObject cacheEmbeddedObjectByIdentifier:self];
        else
            return obj;
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
    NSDictionary *dictionary = [string objectFromJSONString];

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
    assert(_embeddedObjectCache);
    return _embeddedObjectCache[identifier];
}

- (void)setEmbeddingKey:(NSString *)embeddingKey
{
    if (embeddingKey && _embeddingKey == embeddingKey)
        return;
    
    // should be set only once to a non-null value (shouldn't try setting to non-null value B after setting to A)
    assert(!_embeddingKey || [_embeddingKey isEqualToString:embeddingKey]);
    
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
    if ([val isEqual:value]) return YES;
    
    assert(self.embeddingObject);
    assert(self.embeddingKey);
    
    // FIXME: Continue from here. Infer the key the object has in its embedding object, preferably without introducing new state.
    //[self.embeddingObject.changedNames addObject:property]
    // - Propagate changes further back in the tree
    // - Deal with MPEmbeddedObjects too
    MPManagedObject *o = ((MPManagedObject *)self.embeddingObject);
    
    assert(_properties);
    _properties[property] = value;
    _needsSave = true;
    
    [o cacheValue:value ofProperty:property changed:YES];
    [o markNeedsSave];
    
    return YES;
}


- (void)setIdentifier:(NSString *)identifier
{
    _properties[@"_id"] = identifier;
}

- (NSString *)identifier
{
    return _properties[@"_id"];
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
    return [self.dictionaryRepresentation JSONString];
}

- (BOOL)save:(NSError **)err
{
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

- (void)markNeedsSave
{
    assert(_embeddingObject);
    self.needsSave = true;
    [_embeddingObject markNeedsSave];
}

- (void)markNeedsNoSave
{
    self.needsSave = false;
    
    assert(_embeddingObject);
    for (NSString *propertyKey in [self.class embeddedProperties])
         [[self valueForKey:propertyKey] markNeedsNoSave];
}

#pragma mark - Accessor implementations

- (CBLDatabase *)databaseForModelProperty:(NSString *)property
{
    id<MPEmbeddingObject> embedder = self;
    while (![(embedder = self.embeddingObject) isKindOfClass:[MPManagedObject class]])
    {
        assert(embedder);
    }
    assert([embedder isKindOfClass:[MPManagedObject class]]);
    MPManagedObject *mo = (MPManagedObject *)embedder;
    
    return mo.database;
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
    
    CBLDocument* doc = [[self databaseForModelProperty: property] existingDocumentWithID:rawValue];
    if (!doc)
    {
        MPLog(@"Unable to get document from property %@ of %@ (value='%@')",
             property, doc, rawValue);
        return nil;
    }
    
    // Ask factory to get/create model; if it doesn't know, use the declared class:
    CBLModel *value = [doc.database.modelFactory modelForDocument: doc];
    if (!value)
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
    for (id rawObj in rawValue)
    {
        if (![rawObj isKindOfClass:[NSString class]])
        {
            MPLog(@"Embedded object array typed valued property %@ of %@ contains object other than string: %@", property, self, rawObj);
            return nil;
        }
        
        NSDictionary *dict = [rawObj objectFromJSONString];
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
        
        NSDictionary *dict = [rawObj objectFromJSONString];
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
    else if (value && ![value isKindOfClass:[NSData data]]) {
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

@end