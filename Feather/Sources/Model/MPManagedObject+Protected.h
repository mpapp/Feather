//
//  MPManagedObject+MPManagedObject_Protected.h
//  Feather
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPManagedObject.h"

@interface CouchModel (Protected)

// Private methods defined in CouchModel, needed for setting dictionary embedded values.
- (void) cacheValue: (id)value ofProperty: (NSString*)property changed: (BOOL)changed;
- (void) markNeedsSave;

@end

@interface MPManagedObject (Protected)

@property (readwrite, copy) NSString *objectType;

// publicly read-only
@property (weak, readwrite) MPManagedObjectsController *controller;
@property (readwrite, assign, getter=isShared, setter=setShared:) BOOL isShared;
@property (readwrite, assign) MPManagedObjectModerationState moderationState;
@property (readwrite, copy) NSString *prototypeID;

- (instancetype)initWithNewDocumentForController:(MPManagedObjectsController *)controller properties:(NSDictionary *)properties documentID:(NSString *)identifier;

@end

@interface CouchModel (Private)

@property (strong, readwrite) CouchDocument *document;
@property (strong, readwrite) NSMutableDictionary *properties;
@property (strong, readwrite) NSMutableSet *changedNames;
@property (copy, readonly) NSString *documentID;
- (void)couchDocumentChanged:(CouchDocument *)doc;
- (id)externalizePropertyValue: (id)value;

@end
