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
#import <Feather/NSObject+MPExtensions.h>

@implementation MPCacheableMixin


#pragma mark - Caching

+ (NSDictionary *)cachedPropertiesByClassName

{
    static NSDictionary *cachedProperties = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cachedProperties = [self propertiesOfSubclassesForClass:self matching:^BOOL(Class cls, NSString *key)
        {
            return [key isMatchedByRegex:@"^cached\\w{1,}"] && [cls propertyWithKeyIsReadWrite:key];
        }];
    });
    
    return cachedProperties;
}

- (void)clearCachedValues
{
    NSSet *cachedKeys = [[self class] cachedPropertiesByClassName][NSStringFromClass([self class])];
    for (NSString *cachedKey in cachedKeys)
        [self setValue:nil forKey:cachedKey];
}

- (void)refreshCachedValues
{
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

@end
