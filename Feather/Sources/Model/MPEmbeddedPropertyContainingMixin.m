//
//  MPEmbeddedPropertyContainingMixin.m
//  Feather
//
//  Created by Matias Piipari on 06/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPEmbeddedPropertyContainingMixin.h"
#import "NSObject+MPExtensions.h"
#import "MPEmbeddedObject.h"

@implementation MPEmbeddedPropertyContainingMixin

+ (NSDictionary *)embeddedPropertiesMap
{
    static NSDictionary *embeddedPropertiesMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        embeddedPropertiesMap =
        [[self propertiesOfSubclassesForClass:self
                                     matching:
          ^BOOL(__unsafe_unretained Class cls, NSString *key)
          {
              Class propertyClass = [self classOfProperty:key];
              
              if ([propertyClass isSubclassOfClass:[MPEmbeddedObject class]])
              { return YES; }
              
              return NO;
          }] copy];
        
    });
    
    return embeddedPropertiesMap;
}

+ (NSSet *)embeddedProperties
{
    return [self embeddedPropertiesMap][NSStringFromClass(self)];
}

@end
