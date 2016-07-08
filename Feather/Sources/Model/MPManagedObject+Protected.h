//
//  MPManagedObject+MPManagedObject_Protected.h
//  Feather
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPManagedObject.h"

@import CouchbaseLite;

@class MPEmbeddedObject;

@interface MPManagedObject (Protected)

@property (readwrite, copy, nonnull) NSString *objectType;

// publicly read-only
@property (weak, readwrite, nullable) MPManagedObjectsController *controller;
@property (readwrite, getter=isShared, setter=setShared:) BOOL isShared;
@property (readwrite) MPManagedObjectModerationState moderationState;
@property (readwrite, nullable) MPManagedObject *prototype;

- (void)setEmbeddedObjectArray:(nullable NSArray *)value ofProperty:(nonnull NSString *)property;
- (nullable NSArray<MPEmbeddedObject *> *)getEmbeddedObjectArrayProperty:(nonnull NSString *)property;

- (nullable NSDictionary *)getEmbeddedObjectDictionaryProperty:(nonnull NSString *)property;
- (void)setEmbeddedObjectDictionary:(nullable NSDictionary *)value ofProperty:(nonnull NSString *)property;

- (void)setEmbeddedObject:(nullable MPEmbeddedObject *)embeddedObj ofProperty:(nonnull NSString *)property;
- (nullable MPEmbeddedObject *)getEmbeddedObjectProperty:(nonnull NSString *)property;

- (nullable MPEmbeddedObject *)decodeEmbeddedObject:(nullable id)rawValue embeddingKey:(nonnull NSString *)key;

@property (readwrite, nullable) NSString *cloudKitChangeTag;

@end

// MARK: -

/* MPManagedObject & MPEmbeddedObject need some otherwise private state of CBLModel exposed. */
@interface CBLModel (Private) <MPEmbeddingObject>

- (void)CBLDocumentChanged:(nonnull CBLDocument *)doc;
-   (nonnull id)externalizePropertyValue:(nonnull id)value;
- (void)cacheValue:(nullable id)value ofProperty:(nonnull NSString *)property changed:(BOOL)changed;
- (nullable CBLModel *)getModelProperty:(nonnull NSString *)property;
- (void)markNeedsSave;
- (void)markPropertyNeedsSave:(nonnull NSString *)property;


@end

@interface CBLModel (PrivateExtensions) <MPEmbeddingObject>
@property (strong, readwrite, nullable) CBLDocument *document;

- (void)markNeedsNoSave; // propagates needsSave = false to object's embedded properties
@end
