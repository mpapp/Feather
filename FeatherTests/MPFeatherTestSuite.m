//
//  MPManuscriptsTestSuite.m
//  Manuscripts
//
//  Created by Matias Piipari on 14/02/2013.
//  Copyright (c) 2013 Manuscripts.app Limited. All rights reserved.
//

#import "Feather.h"
#import "MPFeatherTestSuite.h"
#import "MPFeatherTestClasses.h"

#import "NSBundle+MPExtensions.h"
#import "MPDatabasePackageController+Protected.h"

@implementation MPFeatherTestSuite

- (void)setUp
{
    [super setUp];
    
    NSString *sharedPackagePath = [MPShoeboxPackageController sharedDatabasesPath];
    
    BOOL sharedPackageIsForTestBundle = [[sharedPackagePath lastPathComponent] isEqualToString:
                                         [[NSBundle appBundle] bundleNameString]];
    STAssertTrue(sharedPackageIsForTestBundle,
                 @"Test bundle name is the last path component of the shared package path.");
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSError *err = nil;
    
    [MPFeatherTestPackageController sharedPackageController];
    
    STAssertTrue(!err, @"No error should happen with creating the shared databases path");
    
    if (_docRoot)
        STAssertTrue([fm createDirectoryAtPath:_docRoot withIntermediateDirectories:YES attributes:nil error:&err],
                 @"Creating document root succeeded.");
    

    if ([fm fileExistsAtPath:sharedPackagePath]
        && sharedPackageIsForTestBundle
        &! [MPShoeboxPackageController sharedShoeboxControllerInitialized])
    {
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
        NSLog(@"Shared data is in an unexpected path or missing, don't dare to continue: %@",
              sharedPackagePath);
        exit(1);
    }
    
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

// test suites which need to act as a MPDatabasePackageControllerDelegate need to overload this.
- (NSURL *)packageRootURL
{
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

@end