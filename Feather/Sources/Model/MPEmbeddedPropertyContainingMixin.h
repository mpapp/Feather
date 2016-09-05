//
//  MPEmbeddedPropertyContainingMixin.h
//  Feather
//
//  Created by Matias Piipari on 06/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Foundation;

@class MPEmbeddedObject;

@protocol MPEmbeddedPropertyContaining <NSObject>
@optional

/** @return properties of the class whose declared type is a subclass of MPEmbeddedObject. */
+ (NSSet *)embeddedProperties;

/** This callback allows an embedding object to update state derived from this embedded object. */
- (void)willUpdateEmbeddedObject:(nonnull MPEmbeddedObject *)embeddedObject withEmbeddingKey:(nonnull NSString *)embedddingKey;

@end

@interface MPEmbeddedPropertyContainingMixin : NSObject <MPEmbeddedPropertyContaining>
@end
