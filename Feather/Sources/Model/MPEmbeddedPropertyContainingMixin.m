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

static NSMutableDictionary *embeddedPropertiesMaps;
static dispatch_queue_t embeddedPropertyMapQueue;

+ (void)load {
    [super load];
    embeddedPropertyMapQueue = dispatch_queue_create("embedded.property.resolver", DISPATCH_QUEUE_SERIAL);
    embeddedPropertiesMaps = [NSMutableDictionary new];
}

+ (NSDictionary *)embeddedPropertiesMap
{
    __block id o = nil;
    dispatch_sync(embeddedPropertyMapQueue, ^{
        if ((o = embeddedPropertiesMaps[NSStringFromClass(self)])) {
            return;
        }
        
        o = [[self propertiesOfSubclassesForClass:self
                                         matching:
              ^BOOL(__unsafe_unretained Class cls, NSString *key)
              {
                  Class propertyClass = [self classOfProperty:key];
                  
                  if ([propertyClass isSubclassOfClass:[MPEmbeddedObject class]])
                  { return YES; }
                  
                  return NO;
              }] copy];
        
        embeddedPropertiesMaps[NSStringFromClass(self)] = o;
    });
    
    return o;
}

+ (NSSet *)embeddedProperties
{
    return [self embeddedPropertiesMap][NSStringFromClass(self)];
}

- (void)willUpdateEmbeddedObject:(MPEmbeddedObject *)embeddedObject withEmbeddingKey:(NSString *)embedddingKey {
    // intentionally no-op. override in subclasses to do Stuff.
}

@end
