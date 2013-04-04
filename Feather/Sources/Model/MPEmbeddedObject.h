//
//  MPEmbeddedObject.h
//  Feather
//
//  Created by Matias Piipari on 03/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <CouchCocoa/CouchCocoa.h>
#import "MPManagedObject.h"

/** Objects which can embed MPEmbeddedObject instances should conform to this. Note that MPEmbeddedObject itself conforms to MPEmbeddingObject because it can embed other objects (x => y => z). */
@protocol MPEmbeddingObject <NSObject>
@end

@interface MPEmbeddedObject : CouchDynamicObject <MPEmbeddingObject>

@property (readonly, copy) NSString *identifier;

@property (weak) MPManagedObject *embeddingObject;

- (instancetype)initWithEmbeddingObject:(MPManagedObject *)embeddingObject;
- (id)externalize;

/** Returns a subclass of MPEmbeddedObject */
+ (id)embeddedObjectWithJSONString:(NSString *)string;

@end
