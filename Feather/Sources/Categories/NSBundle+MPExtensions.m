//
//  NSBundle+Feather.m
//  Feather
//
//  Created by Matias Piipari on 17/11/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//


#import "NSBundle+MPExtensions.h"


@implementation NSBundle (Feather)

- (NSString *)bundleNameString
{
    NSString *bundleName = self.infoDictionary[(__bridge NSString *)kCFBundleNameKey];
    NSAssert(bundleName, @"Bundle name unexpectedly nil");
    
    return bundleName;
}

- (NSString *)bundleShortVersionString {
    return self.infoDictionary[@"CFBundleShortVersionString"];
}

- (NSString *)bundleVersionString
{
    NSString *version = self.infoDictionary[(__bridge NSString *)kCFBundleVersionKey];
    NSAssert(version, @"Bundle %@ is missing key %@", self, kCFBundleVersionKey);
    
    return version;
}

+ (BOOL)inTestSuite {
    // FIXME: less hacky implementation, please.
    return [[NSProcessInfo processInfo] environment][@"MPUnitTest"] != nil;
}

+ (BOOL)isCommandLineTool
{
    if ([self inTestSuite])
        return NO;
    
    BOOL b = ([NSBundle.mainBundle objectForInfoDictionaryKey:@"NSMainNibFile"] == nil
              && [NSBundle.mainBundle objectForInfoDictionaryKey:@"NSMainStoryboardFile"] == nil);
    
    return b;
}

+ (BOOL)isXPCService
{
    BOOL b = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundlePackageType"] isEqualToString:@"XPC!"];
    return b;
}

static NSMutableDictionary *_bundleSandboxStates = nil;

+ (NSMutableDictionary *)bundleSandboxStates {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _bundleSandboxStates = [NSMutableDictionary new];
    });
    return _bundleSandboxStates;
}

- (BOOL)isSandboxed {
    BOOL isSandboxed = NO;
    
    SecStaticCodeRef staticCode = NULL;
    NSURL *bundleURL = self.bundleURL;
    
    if (_bundleSandboxStates[bundleURL]) {
        return [_bundleSandboxStates[bundleURL] boolValue];
    }
    
    if (SecStaticCodeCreateWithPath((__bridge CFURLRef)bundleURL, kSecCSDefaultFlags, &staticCode) == errSecSuccess) {
        if (SecStaticCodeCheckValidityWithErrors(staticCode, kSecCSBasicValidateOnly, NULL, NULL) == errSecSuccess) {
            SecRequirementRef sandboxRequirement;
            if (SecRequirementCreateWithString(CFSTR("entitlement[\"com.apple.security.app-sandbox\"] exists"), kSecCSDefaultFlags,
                                               &sandboxRequirement) == errSecSuccess)
            {
                OSStatus codeCheckResult = SecStaticCodeCheckValidityWithErrors(staticCode, kSecCSBasicValidateOnly, sandboxRequirement, NULL);
                if (codeCheckResult == errSecSuccess) {
                    isSandboxed = YES;
                }
            }
        }
        CFRelease(staticCode);
    }
    
    _bundleSandboxStates[bundleURL] = @(isSandboxed);

    return isSandboxed;
}


+ (NSBundle *)appBundle
{
    /*
    if ([self inTestSuite])
    {
        static NSBundle *appBundle = nil;
        
        if (appBundle)
            return appBundle;
        
        // test suites should be run with the env var MPExecutableName included.
        // It's used to derive a 'main' class and from it the bundle.
        NSString *executableName = [[NSProcessInfo processInfo] environment][@"MPExecutableName"];
        NSAssert(executableName, @"Failing to recover environment variable 'MPExecutableName' amongst environment variables.");
        
        Class testClass = NSClassFromString(executableName);
        NSAssert(testClass, @"Failing to recover class with with name %@", executableName);
        appBundle = [NSBundle bundleForClass:testClass];
        
        return appBundle;
    }
    else*/
    {
        return [self mainBundle];
    }
}

+ (NSBundle *)XPCServiceBundleWithName:(NSString *)name
{
    NSAssert([name hasSuffix:@".xpc"], @"Name lacks suffix \".xpc\"");
    
    NSBundle *mainBundle = [NSBundle appBundle];
    NSBundle *bundle =
        [NSBundle bundleWithPath:
            [[mainBundle bundlePath] stringByAppendingPathComponent:
                [NSString stringWithFormat:@"Contents/XPCServices/%@", name]]];
    return bundle;
}

@end
