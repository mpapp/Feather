//
//  MPManagedObject+MPManagedObject_Protected.h
//  Feather
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPManagedObject.h"

@import CouchbaseLite;

@interface MPManagedObject (Protected)

@property (readwrite, copy) NSString *objectType;

// publicly read-only
@property (weak, readwrite) MPManagedObjectsController *controller;
@property (readwrite, assign, getter=isShared, setter=setShared:) BOOL isShared;
@property (readwrite, assign) MPManagedObjectModerationState moderationState;
@property (readwrite) MPManagedObject *prototype;

- (instancetype)initWithNewDocumentForController:(MPManagedObjectsController *)controller
                                      properties:(NSDictionary *)properties
                                      documentID:(NSString *)identifier __attribute__((nonnull(1)));

- (void)setEmbeddedObjectArray:(NSArray *)value ofProperty:(NSString *)property;
- (NSArray *)getEmbeddedObjectArrayProperty:(NSString *)property;

- (NSDictionary *)getEmbeddedObjectDictionaryProperty:(NSString *)property;
- (void)setEmbeddedObjectDictionary:(NSDictionary *)value ofProperty:(NSString *)property;

- (void)setEmbeddedObject:(MPEmbeddedObject *)embeddedObj ofProperty:(NSString *)property;
- (MPEmbeddedObject *)getEmbeddedObjectProperty:(NSString *)property;

- (MPEmbeddedObject *)decodeEmbeddedObject:(id)rawValue embeddingKey:(NSString *)key;

@end

// MARK: -

/* MPManagedObject & MPEmbeddedObject need some otherwise private state of CBLModel exposed. */
@interface CBLModel (Private) <MPEmbeddingObject>

- (void)CBLDocumentChanged:(CBLDocument *)doc;
-   (id)externalizePropertyValue: (id)value;
- (void)cacheValue:(id)value ofProperty:(NSString *)property changed:(BOOL)changed;
- (CBLModel *)getModelProperty:(NSString*)property;
- (void)markNeedsSave;
- (void)markPropertyNeedsSave:(NSString*)property;


@end

@interface CBLModel (PrivateExtensions) <MPEmbeddingObject>
@property (strong, readwrite) CBLDocument *document;

- (void)markNeedsNoSave; // propagates needsSave = false to object's embedded properties
@end