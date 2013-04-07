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

#import "Mixin.h"

#import <CouchCocoa/CouchCocoa.h>
#import <CouchCocoa/CouchModelFactory.h>
#import <CouchCocoa/RESTBody.h>

#import <objc/runtime.h>

/* A private class for saving embedded objects. */
@interface MPSaveOperation : NSObject <MPWaitingOperation>

@property (readwrite, strong) MPEmbeddedObject *embeddedObject;
@property (readwrite, strong) id<MPWaitingOperation> embeddingSaveOperation;

- (instancetype)initWithEmbeddedObject:(MPEmbeddedObject *)embeddedObject;

@end

@interface MPEmbeddedObject ()
{
    NSMutableSet *_changedNames;
}
@end

@implementation MPEmbeddedObject

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

- (instancetype)initWithJSONString:(NSString *)jsonString embeddingObject:(id<MPEmbeddingObject>)embeddingObject embeddingKey:(NSString *)key
{
    NSMutableDictionary *propertiesDict = [jsonString objectFromJSONString];
    return [self initWithDictionary:propertiesDict embeddingObject:embeddingObject embeddingKey:key];
}

- (instancetype)initWithDictionary:(NSDictionary *)propertiesDict embeddingObject:(id<MPEmbeddingObject>)embeddingObject embeddingKey:(NSString *)key
{
    if (self = [super init])
    {
        assert([propertiesDict isKindOfClass:[NSDictionary class]]);
        assert(propertiesDict[@"_id"]);
        assert(propertiesDict[@"objectType"]);
        assert([propertiesDict[@"objectType"] isEqualToString:NSStringFromClass(self.class)]);
        assert(key);
        
        _embeddingKey = key;
        _embeddingObject = embeddingObject;
        
        _properties = [propertiesDict mutableCopy];
        _changedNames = [NSMutableSet setWithCapacity:10];
    }
    
    return self;
}

- (instancetype)initWithEmbeddingObject:(id<MPEmbeddingObject>)embeddingObject
{
    if (self = [super init])
    {
        assert(embeddingObject);
        
        self.embeddingObject = embeddingObject;
        
        _properties = [NSMutableDictionary dictionaryWithCapacity:10];
        _properties[@"_id"] = [NSString stringWithFormat:@"%@:%@",
                               NSStringFromClass([self class]), [[NSUUID UUID] UUIDString]];
        _properties[@"objectType"] = NSStringFromClass([self class]);
    
        _changedNames = [NSMutableSet setWithCapacity:10];
    }
    
    return self;
}

+ (instancetype)embeddedObjectWithJSONString:(NSString *)string
                             embeddingObject:(id<MPEmbeddingObject>)embeddingObject
                                embeddingKey:(NSString *)key
{
    if (!string) return nil;
    
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

    return [[cls alloc] initWithDictionary:dictionary embeddingObject:embeddingObject embeddingKey:key];
}

#pragma mark - 

- (NSMutableSet *)changedNames
{
    return _changedNames;
}

- (id)getValueOfProperty:(NSString *)property
{
    return _properties[property];
}

- (BOOL)setValue:(id)value ofProperty:(NSString *)property
{
    id val = [self getValueOfProperty:property];
    if ([val isEqualToValue:value]) return YES;
    
    assert(self.embeddingObject);
    assert(self.embeddingKey);
    assert([[self embeddingObject] changedNames]);
    
    // FIXME: Continue from here. Infer the key the object has in its embedding object, preferably without introducing new state.
    //[self.embeddingObject.changedNames addObject:property]
    // - Propagate changes further back in the tree
    // - Deal with MPEmbeddedObjects too
    MPManagedObject *o = ((MPManagedObject *)self.embeddingObject);
    
    assert(_properties);
    _properties[property] = value;
    _needsSave = true;
    
    [o.changedNames addObject:self.embeddingKey];
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

// Adapted from CouchCocoa's CouchModel
// Transforms cached property values back into JSON-compatible objects
- (id)externalizePropertyValue:(id)value
{
    if ([value isKindOfClass:[NSData class]])
    {
        value = [RESTBody base64WithData:value];
    }
    else if ([value isKindOfClass:[NSDate class]])
    {
        value = [RESTBody JSONObjectWithDate:value];
    }
    else if ([value isKindOfClass:[CouchModel class]])
    {
        assert([value document]);
        value = [[value document] documentID];
    }
    else if ([value isKindOfClass:[MPEmbeddedObject class]])
    {
        value = [value externalize];
    }
    
    return value;
}

- (id)externalize
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:self.properties.count];
    
    for (id key in _properties)
        dict[key] = [self externalizePropertyValue:_properties[key]];
    
    return [dict JSONString];
}

- (MPSaveOperation *)save
{
    return [[MPSaveOperation alloc] initWithEmbeddedObject:self];
}

- (void)markNeedsSave
{
    assert(_embeddingObject);
    [_embeddingObject markNeedsSave];
}

- (void)markNeedsNoSave
{
    self.needsSave = false;
    
    assert(_embeddingObject);
    for (NSString *propertyKey in [self.class embeddedProperties])
         [[self valueForKey:propertyKey] markNeedsNoSave];
    
    [_changedNames removeAllObjects];
}

#pragma mark - Accessor implementations

- (CouchDatabase *)databaseForModelProperty:(NSString *)property
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
- (CouchModel *)getModelProperty:(NSString *)property
{
    NSString* rawValue = [self getValueOfProperty: property];
    if (!rawValue)
        return nil;
    
    // Look up the CouchDocument:
    if (![rawValue isKindOfClass: [NSString class]]) {
        MPLog(@"Model-valued property %@ of %@ is not a string", property, self);
        return nil;
    }
    
    CouchDocument* doc = [[self databaseForModelProperty: property] documentWithID:rawValue];
    if (!doc)
    {
        MPLog(@"Unable to get document from property %@ of %@ (value='%@')",
             property, doc, rawValue);
        return nil;
    }
    
    // Ask factory to get/create model; if it doesn't know, use the declared class:
    CouchModel* value = [doc.database.modelFactory modelForDocument: doc];
    if (!value) {
        Class declaredClass = [[self class] classOfProperty: property];
        value = [declaredClass modelForDocument: doc];
        if (!value)
            MPLog(@"Unable to instantiate %@ from %@ -- property %@ of %@ (%@)",
                 declaredClass, doc, property, self, self);
    }
    return value;
}

- (NSDate *)getDateProperty:(NSString *)property
{
    id value = _properties[property];
    
    if ([value isKindOfClass:[NSString class]])
        { value = [RESTBody dateWithJSONObject:value]; }
    
    if (value && ![value isKindOfClass:[NSDate class]])
        { MPLog(@"Unable to decode date from property %@ of %@", property, self); return nil; }
    
    //if (value)
    //    [self cacheValue: value ofProperty: property changed: NO];
    
    
    return value;
}

- (NSData *)getDataProperty:(NSString *)property
{
    id value = _properties[property];
    
    if ([value isKindOfClass:[NSString class]])
        { value = [RESTBody dataWithBase64:value]; }
    else if (value && ![value isKindOfClass:[NSData data]])
        { MPLog(@"Unable to decode Base64 data from property %@ of %@", property, self); return nil; }
    
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
    } else if ([propertyClass isSubclassOfClass: [CouchModel class]])
    {
        return imp_implementationWithBlock(^id(MPEmbeddedObject *receiver)
        {
            return [receiver getModelProperty:property];
        });
    } else
    {
        return NULL;  // Unsupported
    }
}

- (void)setModel:(CouchModel *)model forProperty:(NSString *)property
{
    if (_properties[property] &&
        ([_properties[property] isEqualToString:model.document.documentID] ||
         !(_properties[property] && !model))) return;
        
    assert(model.document);
    _properties[property] = model.document.documentID;
    [self markNeedsSave];
}

+ (IMP)impForSetterOfProperty:(NSString *)property ofClass:(Class)propertyClass
{
    if ([propertyClass isSubclassOfClass:[CouchModel class]])
    {
        return imp_implementationWithBlock(^(MPEmbeddedObject *receiver, CouchModel* value)
        {
            [receiver setModel:value forProperty:property];
        });
    } else
    {
        return [super impForSetterOfProperty:property ofClass:propertyClass];
    }
}

+ (IMP)impForGetterOfProperty:(NSString *)property ofType:(const char *)propertyType
{
    if (propertyType[0] == _C_ULNG_LNG)
    {
        return imp_implementationWithBlock(^unsigned long long(CouchDynamicObject* receiver) {
            return [[receiver getValueOfProperty:property] unsignedLongValue];
        });
    }
    else if (propertyType[0] == _C_LNG_LNG)
    {
        return imp_implementationWithBlock(^long long(CouchDynamicObject* receiver) {
            return [[receiver getValueOfProperty:property] longLongValue];
        });
    }
    
    return [super impForGetterOfProperty:property ofType:propertyType];
}

+ (IMP)impForSetterOfProperty:(NSString *)property ofType:(const char *)propertyType
{
    if (propertyType[0] == _C_ULNG_LNG)
    {
        return imp_implementationWithBlock(^(CouchDynamicObject* receiver, unsigned long long value) {
            [receiver setValue:[NSNumber numberWithUnsignedLongLong:value] ofProperty:property];
        });
    }
    else if (propertyType[0] == _C_LNG_LNG)
    {
        return imp_implementationWithBlock(^(CouchDynamicObject* receiver, long long value) {
            [receiver setValue:[NSNumber numberWithLongLong:value] ofProperty:property];
        });
    }
    
    return [super impForSetterOfProperty:property ofType:propertyType];
}

@end

#pragma mark - saving

@implementation MPSaveOperation

- (instancetype)initWithEmbeddedObject:(MPEmbeddedObject *)embeddedObject
{
    if (self = [super init])
    {
        _embeddedObject = embeddedObject;
        _embeddingSaveOperation = [_embeddedObject.embeddingObject save];
    }
    
    return self;
}

- (BOOL)wait
{
    assert(_embeddingSaveOperation);
    return [_embeddingSaveOperation wait];
}

@end