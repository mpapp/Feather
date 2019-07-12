//
//  MPCacheableMixin.m
//  Feather
//
//  Created by Matias Piipari on 03/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPCacheableMixin.h"
#import "MPException.h"
@import FeatherExtensions;
@import ObjectiveC;

@implementation MPCacheableMixin


#pragma mark - Caching

+ (NSDictionary *)cachedPropertiesByClassNameForBaseClass:(Class)cls
{
    NSString *cachedPropertiesKey
    = [NSString stringWithFormat:@"cachedPropertiesFor%@", NSStringFromClass(cls)];
    
    NSDictionary *cachedProperties = objc_getAssociatedObject(cls, NSSelectorFromString(cachedPropertiesKey));
    
    if (!cachedProperties) {
        cachedProperties
        = [cls propertiesOfSubclassesForClass:cls matching:
           ^BOOL(Class cls, NSString *key) {
               BOOL hasCachedPrefix = [key isMatchedByRegex:@"^cached\\w{1,}"];
               BOOL isReadwrite = [cls propertyWithKeyIsReadWrite:key];
               
               return hasCachedPrefix && isReadwrite;
           }];
        
        objc_setAssociatedObject(cls, NSSelectorFromString(cachedPropertiesKey),
                                 cachedProperties, OBJC_ASSOCIATION_RETAIN);
    }
    
    return cachedProperties;
}

+ (NSDictionary *)cachedPropertiesByClassName
{
    return [self cachedPropertiesByClassNameForBaseClass:self];
}

+ (void)clearCachedValues:(id<MPCacheable>)cacheable {
    if (cacheable.class.hasMainThreadIsolatedCachedProperties) {
        NSAssert(NSThread.isMainThread, @"Class %@ has main thread isolated cached properties", cacheable.class);
    }
    
    NSSet *cachedKeys = [cacheable.class cachedPropertiesByClassName][NSStringFromClass(cacheable.class)];
    
    for (NSString *cachedKey in cachedKeys) {
        [(id)cacheable setValue:nil forKey:cachedKey];
    }
}

- (void)clearCachedValues {
    [self.class clearCachedValues:self];
}

- (void)refreshCachedValues {
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

@end
