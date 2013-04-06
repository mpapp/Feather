//
//  MPEmbeddedObject.h
//  Feather
//
//  Created by Matias Piipari on 03/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <CouchCocoa/CouchCocoa.h>
#import "MPEmbeddedPropertyContainingMixin.h"

@protocol MPWaitingOperation;

/** Protocol used to mark objects which can embed MPEmbeddedObject instances. */
@protocol MPEmbeddingObject <MPEmbeddedPropertyContaining, NSObject>

- (id<MPWaitingOperation>)save;

@property (readonly) bool needsSave;

/** Propagates needsSave = true towards embedding object. */
- (void)markNeedsSave;

/** Propagates needsSave = false through the embedded properties of the object. */
- (void)markNeedsNoSave;

@property (readonly, strong) NSMutableSet *changedNames;

@end

/** Protocol used to mark operations which can be made to wait until any pending network activity is finished.
  * @return  YES on a successfully finished operation, NO on error. */
@protocol MPWaitingOperation <NSObject>
- (BOOL)wait;
@end

#pragma mark - 

/** A model object that can be embedded as values in MPManagedObject's keys. 
  * MPEmbeddedObject itself conforms to MPEmbeddingObject because it can embed other objects. */
@interface MPEmbeddedObject : CouchDynamicObject <MPEmbeddingObject>

@property (readonly, copy) NSString *identifier;

@property (weak, readonly) id<MPEmbeddingObject> embeddingObject;
@property (copy, readonly) NSString *embeddingKey;

@property (readonly, strong) NSMutableSet *changedNames;

- (CouchDatabase *)databaseForModelProperty:(NSString *)property;

- (instancetype)initWithEmbeddingObject:(id<MPEmbeddingObject>)embeddingObject;

/** Returns a JSON encodable version of the embedded object. */
- (NSString *)externalize;

/** Returns an MPEmbeddedObject instance for a JSON string. 
  * The class of the object is determined by its 'objectType' property. */
+ (id)embeddedObjectWithJSONString:(NSString *)string
                   embeddingObject:(id<MPEmbeddingObject>)embeddingObject
                      embeddingKey:(NSString *)key;

@end

@interface RESTOperation (MPWaitingOperation) <MPWaitingOperation>
@end