//
//  MPEmbeddedObject.h
//  Feather
//
//  Created by Matias Piipari on 03/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <CouchbaseLite/CouchbaseLite.h>
#import "MPEmbeddedPropertyContainingMixin.h"


@protocol MPWaitingOperation;
@class MPEmbeddedObject;

/** Protocol used to mark objects which can embed MPEmbeddedObject instances. */
@protocol MPEmbeddingObject <MPEmbeddedPropertyContaining, NSObject>

@property (readonly) bool needsSave;

/** Propagates needsSave = true towards embedding object. */
- (void)markNeedsSave;

/** Propagates needsSave = false through the embedded properties of the object. */
- (void)markNeedsNoSave;

- (BOOL)save:(NSError **)err;

@property (readonly, strong) NSMutableSet *changedNames;

@optional
/** Returns an embedded object with the specified identifier */
- (MPEmbeddedObject *)embeddedObjectWithIdentifier:(NSString *)identifier;

- (void)cacheEmbeddedObjectByIdentifier:(MPEmbeddedObject *)obj;

@end

#pragma mark -

/** A model object that can be embedded as values in MPManagedObject's keys. 
  * MPEmbeddedObject itself conforms to MPEmbeddingObject because it can embed other objects. */
NS_REQUIRES_PROPERTY_DEFINITIONS
@interface MPEmbeddedObject : MYDynamicObject <MPEmbeddingObject>

@property (readonly, copy) NSString *identifier;

@property (weak, readonly) id<MPEmbeddingObject> embeddingObject;
@property (copy, readonly) NSString *embeddingKey;

@property (readonly, strong) NSMutableSet *changedNames;

- (CBLDatabase *)databaseForModelProperty:(NSString *)property;

- (instancetype)initWithEmbeddingObject:(id<MPEmbeddingObject>)embeddingObject embeddingKey:(NSString *)embeddingKey;

- (instancetype)initWithDictionary:(NSDictionary *)propertiesDict
                   embeddingObject:(id<MPEmbeddingObject>)embeddingObject
                      embeddingKey:(NSString *)key;

/** Returns JSON-encodable dictionary representation of this embedded object. */
- (NSDictionary *)dictionaryRepresentation;

/** Returns a JSON encodable version of the embedded object. */
- (NSString *)externalize;

/** Returns an MPEmbeddedObject instance for a JSON string. 
  * The class of the object is determined by its 'objectType' property. */
+ (instancetype)embeddedObjectWithJSONString:(NSString *)string
                             embeddingObject:(id<MPEmbeddingObject>)embeddingObject
                                embeddingKey:(NSString *)key;

+ (instancetype)embeddedObjectWithDictionary:(NSDictionary *)dictionary
                             embeddingObject:(id<MPEmbeddingObject>)embeddingObject
                                embeddingKey:(NSString *)key;

- (BOOL)save:(NSError *__autoreleasing *)outError;

/** Saves, and on error posts an error notification to object's embedded object's package controller's notification center. */
- (BOOL)save;

@end