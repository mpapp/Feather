//
//  MPManagedObject+MPManagedObject_Protected.h
//  Feather
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPManagedObject.h"

@interface MPManagedObject (Protected)

@property (readwrite, copy) NSString *objectType;

// publicly read-only
@property (weak, readwrite) MPManagedObjectsController *controller;
@property (readwrite, assign, getter=isShared, setter=setShared:) BOOL isShared;
@property (readwrite, assign) MPManagedObjectModerationState moderationState;
@property (readwrite, copy) NSString *prototypeID;

- (instancetype)initWithNewDocumentForController:(MPManagedObjectsController *)controller properties:(NSDictionary *)properties documentID:(NSString *)identifier;

@end

#pragma mark -

/* MPManagedObject & MPEmbeddedObject need some otherwise private state of CouchModel exposed. */
@interface CouchModel (Private) <MPEmbeddingObject>

- (void)couchDocumentChanged:(CouchDocument *)doc;
-   (id)externalizePropertyValue: (id)value;
- (void)cacheValue:(id)value ofProperty:(NSString *)property changed:(BOOL)changed;
- (CouchModel*) getModelProperty: (NSString*)property;
- (void)markNeedsSave;

@end

@interface CouchModel (PrivateExtensions) <MPEmbeddingObject>
@property (strong, readwrite) CouchDocument *document;
@property (strong, readonly) NSMutableDictionary *properties;
@property (strong, readonly) NSMutableSet *changedNames;

- (void)markNeedsNoSave; // propagates needsSave = false to object's embedded properties
@end