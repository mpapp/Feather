//
//  MPManuscriptsTestSuite.m
//  Manuscripts
//
//  Created by Matias Piipari on 14/02/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "Feather.h"
#import "MPFeatherTestSuite.h"
#import "MPManagedObject.h"

#import "NSBundle+MPExtensions.h"
#import "NSArray+MPExtensions.h"
#import "MPDatabasePackageController+Protected.h"
#import "RegexKitLite.h"

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
    
    [self createPackageRootDirectory];
    [self createSharedPackageRootDirectory];
    
    if ([fm fileExistsAtPath:sharedPackagePath]
        && sharedPackageIsForTestBundle
        && ![MPShoeboxPackageController sharedShoeboxControllerInitialized])
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
        
        MPShoeboxPackageController *sharedPackage = [MPShoeboxPackageController sharedShoeboxController];
        STAssertTrue(sharedPackage != nil, @"A shared package controller initialized");
        
    } else if (!sharedPackageIsForTestBundle)
    {
        NSLog(@"Shared data is in an unexpected path or missing, don't dare to continue: %@",
              sharedPackagePath);
        exit(1);
    }
    
    [self loadSharedFixtures];
}

- (void)createPackageRootDirectory
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    if (_testPackageRootDirectory)
        STAssertTrue([fm createDirectoryAtPath:_testPackageRootDirectory withIntermediateDirectories:YES
                                    attributes:nil error:&err],
                     @"Creating document root succeeded.");
    
    STAssertTrue(!err, @"No error should happen with creating the package root directory");
}

- (void)createSharedPackageRootDirectory
{
    NSError *err = nil;
    [MPShoeboxPackageController createSharedDatabasesPathWithError:&err];
    STAssertTrue(!err, @"No error should happen with creating the shared package root directory");
}

- (NSArray *)loadFixturesForManagedObjectClass:(Class)class
                           toPackageController:(MPDatabasePackageController *)pkgc
                              fromJSONResource:(NSString *)resource
{
    NSError *err = nil;
    MPManagedObjectsController *moc = [pkgc controllerForManagedObjectClass:class];
    
    NSURL *url = [[NSBundle appBundle] URLForResource:resource withExtension:@"json"];
    NSArray *objs = [moc objectsFromContentsOfArrayJSONAtURL:url
                                                       error:&err];
    
    STAssertTrue(!err, [NSString stringWithFormat:@"No error occurred loading fixtures from %@", url]);
    
    return objs;
}

- (void)loadSharedFixtures
{
    NSError *err = nil;
    NSArray *urls = [NSBundle URLsForResourcesWithExtension:@"json" subdirectory:@""
                                            inBundleWithURL:[[NSBundle appBundle] bundleURL]];
    
    MPShoeboxPackageController *spkg = [MPShoeboxPackageController sharedShoeboxController];
    
    for (NSURL *url in urls)
    {
        NSString *name = [url lastPathComponent];
        
        Class cls =
            NSClassFromString(
                [[name componentsMatchedByRegex:@"(\\S+)-fixtures.json" capture:1] firstObject]);
        
        if ([cls isSubclassOfClass:[MPManagedObject class]])
        {
            MPManagedObjectsController *moc = [spkg controllerForManagedObjectClass:cls];
            if (!moc) continue;
            
            NSArray *objs = [moc objectsFromContentsOfArrayJSONAtURL:url error:&err];
            
            MPLog(@"Loaded %lu fixture objects from %@", objs.count, url);
            
            if (err) break;
        }
    }
    
    STAssertTrue(!err, @"Loading fixtures succeeds.");
}

- (void)tearDown
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (_testPackageRootDirectory && [fm fileExistsAtPath:_testPackageRootDirectory])
    {
        NSError *err = nil;
        STAssertTrue([fm removeItemAtPath:_testPackageRootDirectory error:&err], @"Deleting document root succeeded.");
    }
    
#if MP_DEBUG_ZOMBIE_MODELS
    [MPManagedObject clearModelObjectMap];
#endif
    
    [super tearDown];
}

// test suites which need to act as a MPDatabasePackageControllerDelegate need to overload this.
- (NSURL *)packageRootURL
{
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

@end