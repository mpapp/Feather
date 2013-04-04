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

@interface MPEmbeddedObject ()
@property (readonly) NSMutableDictionary *properties;
@end

@implementation MPEmbeddedObject

- (instancetype)init
{
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

- (instancetype)initWithJSONString:(NSString *)jsonString embeddingObject:(id<MPEmbeddingObject>)embeddingObject
{
    NSMutableDictionary *propertiesDict = [jsonString objectFromJSONString];
    return [self initWithDictionary:propertiesDict embeddingObject:embeddingObject];
}

- (instancetype)initWithDictionary:(NSDictionary *)propertiesDict embeddingObject:(id<MPEmbeddingObject>)embeddingObject
{
    if (self = [super init])
    {
        assert([propertiesDict isKindOfClass:[NSDictionary class]]);
        assert(propertiesDict[@"_id"]);
        assert(propertiesDict[@"objectType"]);
        assert([propertiesDict[@"objectType"] isEqualToString:NSStringFromClass(self.class)]);
        
        _properties = [propertiesDict mutableCopy];
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
        _properties[@"_id"] = [[NSUUID UUID] UUIDString];
        _properties[@"objectType"] = NSStringFromClass([self class]);
    }
    
    return self;
}

+ (id)embeddedObjectWithJSONString:(NSString *)string embeddingObject:(id<MPEmbeddingObject>)embeddingObject;
{
    return [[self alloc] initWithJSONString:string embeddingObject:embeddingObject];
}

#pragma mark - 

- (id)getValueOfProperty:(NSString *)property
{
    return _properties[property];
}

- (BOOL)setValue:(id)value ofProperty:(NSString *)property
{
    id val = [self getValueOfProperty:property];
    if ([val isEqualToValue:value]) return YES;
    
    assert(self.embeddingObject);
    
    // FIXME: Continue from here. Infer the key the object has in its embedding object, preferably without introducing new state.
    //[self.embeddingObject.changedNames addObject:property]
    
    return NO;
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

@end
