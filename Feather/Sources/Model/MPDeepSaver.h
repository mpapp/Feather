//
//  MPDeepSaver.h
//  Feather
//
//  Created by Matias Piipari on 23/05/2015.
//  Copyright (c) 2015 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MPEmbeddingObject;

/** A utility that saves object graphs of id<MPEmbeddingObject>. */
@interface MPDeepSaver : NSObject

+ (BOOL)deepSave:(id<MPEmbeddingObject>)o;

+ (BOOL)deepSave:(id<MPEmbeddingObject>)o error:(NSError *__autoreleasing *)outError;

@end
