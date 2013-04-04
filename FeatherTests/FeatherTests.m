//
//  MPManuscriptsTestSuite.m
//  Manuscripts
//
//  Created by Matias Piipari on 14/02/2013.
//  Copyright (c) 2013 Manuscripts.app Limited. All rights reserved.
//

#import "FeatherTests.h"
#import <Feather/Feather.h>
#import "NSBundle+MPExtensions.h"

@implementation MPFeatherTestSuite

- (void)setUp
{
    [super setUp];
    
    NSString *sharedPackagePath = [MPShoeboxPackageController sharedDatabasesPath];
    
    BOOL sharedPackageIsForMainBundle = [[sharedPackagePath lastPathComponent] isEqualToString:
                                         [[NSBundle mainBundle] bundleNameString]];
    STAssertFalse(sharedPackageIsForMainBundle,
                  @"Main bundle name is *not* the last path component of the shared package path.");
    
    BOOL sharedPackageIsForTestBundle = [[sharedPackagePath lastPathComponent] isEqualToString:
                                         [[NSBundle appBundle] bundleNameString]];
    STAssertTrue(sharedPackageIsForTestBundle,
                 @"Test bundle name is the last path component of the shared package path.");
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:sharedPackagePath] && sharedPackageIsForTestBundle)
    {
        if ([MPShoeboxPackageController sharedShoeboxControllerInitialized]) return;
        
        NSError *err = nil;
        [fm removeItemAtPath:sharedPackagePath error:&err];
        
        if (err)
        {
            NSLog(@"ERROR! Could not delete shared package data: %@", err);
            exit(1);
        }
        
        STAssertTrue(![MPShoeboxPackageController sharedShoeboxControllerInitialized],
                     @"There should be no shared package controller before its path has been created.");
        
        STAssertTrue(
                     [fm createDirectoryAtPath:sharedPackagePath withIntermediateDirectories:NO attributes:nil error:&err],
                     [NSString stringWithFormat:@"Failed to create shared package directory root: %@", err]);
        
        MPFeatherTestPackageController *sharedPackage = [MPFeatherTestPackageController sharedPackageController];
        STAssertTrue(sharedPackage != nil, @"Shared package controller initialized");
        
    } else if (!sharedPackageIsForTestBundle)
    {
        NSLog(@"Shared data is in an unexpected path, don't dare to continue: %@",
              sharedPackagePath);
        exit(1);
    }
    
    NSError *err = nil;
    STAssertTrue([fm createDirectoryAtPath:_docRoot withIntermediateDirectories:YES attributes:nil error:&err],
                 @"Creating document root succeeded.");
    
    err = nil;
}

- (void)tearDown
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (_docRoot && [fm fileExistsAtPath:_docRoot])
    {
        NSError *err = nil;
        STAssertTrue([fm removeItemAtPath:_docRoot error:&err], @"Deleting document root succeeded.");
    }
    
    [super tearDown];
}

- (NSURL *)packageRootURL
{
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

@end

@implementation MPFeatherTestPackageController

+ (void)initialize
{
    if (self == [MPFeatherTestPackageController class])
    {
        [self registerShoeboxPackageControllerClass:self];
    }
}

+ (instancetype)sharedPackageController
{
    MPFeatherTestPackageController *tpc = [MPFeatherTestPackageController sharedShoeboxController];
    assert([tpc isKindOfClass:[MPFeatherTestPackageController class]]);
    return tpc;
}

@end
