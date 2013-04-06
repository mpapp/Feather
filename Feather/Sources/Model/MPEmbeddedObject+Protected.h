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

@end
