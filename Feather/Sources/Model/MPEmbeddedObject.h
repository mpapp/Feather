//
//  MPEmbeddedObject.h
//  Feather
//
//  Created by Matias Piipari on 03/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <CouchCocoa/CouchCocoa.h>

/** Protocol used to tag objects which can embed MPEmbeddedObject instances. */
@protocol MPEmbeddingObject <NSObject>
@end

/** MPEmbeddedObject itself conforms to MPEmbeddingObject because it can embed other objects. */
@interface MPEmbeddedObject : CouchDynamicObject <MPEmbeddingObject>

@property (readonly, copy) NSString *identifier;

@property (weak) id<MPEmbeddingObject> embeddingObject;

- (instancetype)initWithEmbeddingObject:(id<MPEmbeddingObject>)embeddingObject;

/** Returns a JSON encodable version of the embedded object. */
- (NSString *)externalize;

/** Returns an MPEmbeddedObject instance for a JSON string. 
  * The class of the object is determined by its 'objectType' property. */
+ (id)embeddedObjectWithJSONString:(NSString *)string
                   embeddingObject:(id<MPEmbeddingObject>)embeddingObject;

@end
