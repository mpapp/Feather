//
//  NSBundle+Feather.m
//  Feather
//
//  Created by Matias Piipari on 17/11/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Feather/NSBundle+MPExtensions.h>

#import <P2Core/NSString+P2Extensions.h>


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

+ (BOOL)isCommandLineTool
{
    BOOL b = ([[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSMainNibFile"] == nil); // TODO: this is not very airtight logic
    return b;
}

+ (BOOL)isXPCService
{
    BOOL b = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundlePackageType"] isEqualToString:@"XPC!"];
    return b;
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
    /*else if ([self isCommandLineTool] || [self isXPCService])
    {
        NSString *executablePath = [[[[NSProcessInfo processInfo] arguments][0] stringByStandardizingPath] stringByResolvingSymlinksInPath];
        NSString *bundlePath = [executablePath substringUpTo:@".app"];
        assert(bundlePath);
        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        return bundle;
    }*/
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