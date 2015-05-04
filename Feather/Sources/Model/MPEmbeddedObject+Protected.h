//
//  MPEmbeddedObject_Protected.h
//  Feather
//
//  Created by Matias Piipari on 05/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Feather/Feather.h>
#import "MPEmbeddedObject.h"

@interface MPEmbeddedObject ()

@property (readwrite, weak) id<MPEmbeddingObject> embeddingObject;
@property (copy) NSString *embeddingKey;
@property (readonly) NSMutableDictionary *properties;

@property (readwrite) bool needsSave;

/** Caches the value of a specified property, and optionally marks the object as having been changed.
  * You should not need to call this method anywhere other than internally in MPEmbeddedObject: it's
  * modelled after the same method in CBLModel, and it is used to propagate the notice of changed embedded objects 
  * all the way to the embedding object. */
- (void)cacheValue:(id)value ofProperty:(NSString *)property changed:(BOOL)changed;

@end
