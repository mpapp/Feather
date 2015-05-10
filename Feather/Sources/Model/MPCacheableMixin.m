//
//  MPCacheableMixin.m
//  Feather
//
//  Created by Matias Piipari on 03/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPCacheableMixin.h"
#import "RegexKitLite.h"
#import "MPException.h"
#import <FeatherExtensions/FeatherExtensions.h>

#import <objc/runtime.h>

@implementation MPCacheableMixin


#pragma mark - Caching

+ (NSDictionary *)cachedPropertiesByClassName
{
    NSString *cachedPropertiesKey
        = [NSString stringWithFormat:@"cachedPropertiesFor%@", NSStringFromClass(self)];
    
    NSDictionary *cachedProperties = objc_getAssociatedObject(self, [cachedPropertiesKey UTF8String]);
    
    if (!cachedProperties)
    {
        cachedProperties
            = [self propertiesOfSubclassesForClass:self matching:^BOOL(Class cls, NSString *key)
        {
            return [key isMatchedByRegex:@"^cached\\w{1,}"] && [cls propertyWithKeyIsReadWrite:key];
        }];

        objc_setAssociatedObject(self, [cachedPropertiesKey UTF8String],
                                 cachedProperties, OBJC_ASSOCIATION_RETAIN);
    }
    
    return cachedProperties;
}

- (void)clearCachedValues {
    if (self.class.hasMainThreadIsolatedCachedProperties)
        NSAssert(NSThread.isMainThread, @"Class %@ has main thread isolated cached properties", self.class);
    
    NSSet *cachedKeys = [[self class] cachedPropertiesByClassName][NSStringFromClass([self class])];
    for (NSString *cachedKey in cachedKeys)
        [self setValue:nil forKey:cachedKey];
}

- (void)refreshCachedValues {
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

@end
