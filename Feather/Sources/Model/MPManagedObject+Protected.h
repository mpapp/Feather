//
//  MPManagedObject+MPManagedObject_Protected.h
//  Manuscripts
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
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
