//
//  NSBundle+Manuscripts.m
//  Manuscripts
//
//  Created by Matias Piipari on 17/11/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
//

#import <Feather/NSBundle+MPExtensions.h>

@implementation NSBundle (Manuscripts)

- (NSString *)bundleNameString
{
    return self.infoDictionary[(__bridge NSString *)kCFBundleNameKey];
}

- (NSString *)bundleVersionString
{
    return self.infoDictionary[(__bridge NSString *)kCFBundleVersionKey];
}

/** Returns the main bundle for non-unit test targets, and the unit test bundle for the unit tests. */
+ (NSBundle *)appBundle
{
    if ([[NSProcessInfo processInfo] environment][@"MPUnitTest"])
    {
        Class testClass = NSClassFromString(@"MPModelTests");
        assert(testClass);
        return [NSBundle bundleForClass:testClass];
    }
    else
    {
        return [self mainBundle];
    }
}

+ (NSBundle *)XPCServiceBundleWithName:(NSString *)name
{
    assert([name hasSuffix:@".xpc"]);
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSBundle *bundle =
        [NSBundle bundleWithPath:
            [[mainBundle bundlePath] stringByAppendingPathComponent:
                [NSString stringWithFormat:@"Contents/XPCServices/%@", name]]];
    return bundle;
}

@end