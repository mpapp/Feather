//
//  NSBundle+Feather.m
//  Feather
//
//  Created by Matias Piipari on 17/11/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Feather/NSBundle+MPExtensions.h>

@implementation NSBundle (Feather)

- (NSString *)bundleNameString
{
    NSString *bundleName = self.infoDictionary[(__bridge NSString *)kCFBundleNameKey];
    assert(bundleName);
    
    return bundleName;
}

- (NSString *)bundleVersionString
{
    NSString *version = self.infoDictionary[(__bridge NSString *)kCFBundleVersionKey];
    assert(version);
    
    return version;
}

+ (BOOL)inTestSuite {
    // FIXME: less hacky implementation, please.
    return [[NSProcessInfo processInfo] environment][@"MPUnitTest"];
}

+ (NSBundle *)appBundle
{
    if ([self inTestSuite])
    {
        static NSBundle *appBundle = nil;
        
        if (appBundle)
            return appBundle;
        
        // test suites should be run with the env var MPExecutableName included.
        // It's used to derive a 'main' class and from it the bundle.
        NSString *executableName = [[NSProcessInfo processInfo] environment][@"MPExecutableName"];
        assert(executableName);
        
        Class testClass = NSClassFromString(executableName);
        assert(testClass);
        appBundle = [NSBundle bundleForClass:testClass];
        
        return appBundle;
    }
    else
    {
        return [self mainBundle];
    }
}

+ (NSBundle *)XPCServiceBundleWithName:(NSString *)name
{
    assert([name hasSuffix:@".xpc"]);
    
    NSBundle *mainBundle = [NSBundle appBundle];
    NSBundle *bundle =
        [NSBundle bundleWithPath:
            [[mainBundle bundlePath] stringByAppendingPathComponent:
                [NSString stringWithFormat:@"Contents/XPCServices/%@", name]]];
    return bundle;
}

@end