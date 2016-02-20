//
//  MPEmbeddedObject.h
//  Feather
//
//  Created by Matias Piipari on 03/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import CouchbaseLite.MYDynamicObject;

#import "MPEmbeddedPropertyContainingMixin.h"

@protocol MPWaitingOperation;
@class MPEmbeddedObject;
@class MPManagedObject;
@class CBLDatabase;

extern NSString *_Nonnull const MPPasteboardTypeEmbeddedObjectFull;
extern NSString *_Nonnull const MPPasteboardTypeEmbeddedObjectID;
extern NSString *_Nonnull const MPPasteboardTypeEmbeddedObjectIDArray;

/** Protocol used to mark objects which can embed MPEmbeddedObject instances. */
@protocol MPEmbeddingObject <MPEmbeddedPropertyContaining, NSObject>

@property (readonly) bool needsSave;

/** Propagates needsSave = true towards embedding object. */
- (void)markNeedsSave;

/** Propagates needsSave = false through the embedded properties of the object. */
- (void)markNeedsNoSave;

- (BOOL)save:(NSError *_Nullable *_Nullable)err;

@optional
/** Returns an embedded object with the specified identifier */
- (nullable MPEmbeddedObject *)embeddedObjectWithIdentifier:(nonnull NSString *)identifier;

- (void)cacheEmbeddedObjectByIdentifier:(nonnull MPEmbeddedObject *)obj;

- (void)cacheValue:(nullable id)value
        ofProperty:(nonnull NSString *)property
           changed:(BOOL)changed;

@end

#pragma mark -

/** A model object that can be embedded as values in MPManagedObject's keys. 
  * MPEmbeddedObject itself conforms to MPEmbeddingObject because it can embed other objects. */
NS_REQUIRES_PROPERTY_DEFINITIONS
@interface MPEmbeddedObject : MYDynamicObject <MPEmbeddingObject, NSPasteboardWriting, NSPasteboardReading>

@property (readonly, copy, nonnull) NSString *identifier;

@property (weak, readonly, nullable) id<MPEmbeddingObject> embeddingObject;
@property (copy, readonly, nullable) NSString *embeddingKey;

@property (readonly, strong, nonnull) NSMutableSet<NSString *> *changedNames;

- (nonnull CBLDatabase *)databaseForModelProperty:(nonnull NSString *)property;

- (nonnull instancetype)initWithEmbeddingObject:(nonnull id<MPEmbeddingObject>)embeddingObject
                                   embeddingKey:(nonnull NSString *)embeddingKey;

- (nonnull instancetype)initWithDictionary:(nonnull NSDictionary *)propertiesDict
                           embeddingObject:(nonnull id<MPEmbeddingObject>)embeddingObject
                              embeddingKey:(nonnull NSString *)key;

/** Returns JSON-encodable dictionary representation of this embedded object. */
- (nonnull NSDictionary *)dictionaryRepresentation;

/** Returns a JSON encodable version of the embedded object. */
- (nonnull NSString *)externalize;

/** The embedding managed object of an embedded object is the managed object found when the path is followed through 'embeddingObject' until a MPManagedObject instance is found. */
@property (readonly, nullable) __kindof MPManagedObject *embeddingManagedObject;

/** Returns an MPEmbeddedObject instance for a JSON string. 
  * The class of the object is determined by its 'objectType' property. */
+ (nonnull instancetype)embeddedObjectWithJSONString:(nonnull NSString *)string
                                     embeddingObject:(nonnull id<MPEmbeddingObject>)embeddingObject
                                        embeddingKey:(nonnull NSString *)key;

+ (nonnull instancetype)embeddedObjectWithDictionary:(nonnull NSDictionary *)dictionary
                                     embeddingObject:(nonnull id<MPEmbeddingObject>)embeddingObject
                                        embeddingKey:(nonnull NSString *)key;

/** Get an embedded object given a dictionary representation that contains a reference to it (used by the pasteboard reader). */
+ (nullable __kindof MPEmbeddedObject *)objectWithReferableDictionaryRepresentation:(nonnull NSDictionary *)referableDictionaryRep;

- (BOOL)save:(NSError *_Nullable __autoreleasing *_Nullable)outError;

/** Saves the object, and all it’s embedded object typed properties, and managed object typed properties.
 * Also sends -deepSave: recursively to all managed and embedded objects referenced by the object. */
- (BOOL)deepSave:(NSError *_Nullable __autoreleasing *_Nullable)outError;

/** Deep saves and posts an error notification on errors to the object's package controller's notification center. */
- (BOOL)deepSave;

/** Saves, and on error posts an error notification to object's embedded object's package controller's notification center. */
- (BOOL)save;

@end