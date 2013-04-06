//
//  MPEmbeddedPropertyContainingMixin.h
//  Feather
//
//  Created by Matias Piipari on 06/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MPEmbeddedPropertyContaining <NSObject>
@optional

/** @return properties of the class whose declared type is a subclass of MPEmbeddedObject. */
+ (NSSet *)embeddedProperties;
@end

@interface MPEmbeddedPropertyContainingMixin : NSObject <MPEmbeddedPropertyContaining>
@end
