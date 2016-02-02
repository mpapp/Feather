//
//  MPManuscriptsTestSuite.m
//  Manuscripts
//
//  Created by Matias Piipari on 14/02/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Feather;

#import "FeatherTests.h"
#import "MPFeatherTestClasses.h"

@import Feather.MPDatabasePackageController_Protected;
@import FeatherExtensions;
@import RegexKitLite;

#import <Feather/MPException.h>

@implementation FeatherTests

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setUp
{
    [super setUp];
    
    NSString *sharedPackagePath = [MPShoeboxPackageController.sharedShoeboxPackageControllerClass sharedDatabasesPath];
    
    BOOL sharedPackageIsForTestBundle = [[sharedPackagePath lastPathComponent] isEqualToString:
                                         [[NSBundle appBundle] bundleNameString]];
    XCTAssertTrue(sharedPackageIsForTestBundle,
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
        
        XCTAssertTrue(![MPShoeboxPackageController sharedShoeboxControllerInitialized],
                     @"There should be no shared package controller before its path has been created.");
        
        XCTAssertTrue([fm createDirectoryAtPath:sharedPackagePath withIntermediateDirectories:NO attributes:nil error:&err],
                     @"Failed to create shared package directory root: %@", err);
        
        // you can optionally include a fixture with name 'shared' along with a folder 'shared attachments' to load the shared database used by the test. 
        NSURL *sharedDBFixture = [[NSBundle appBundle] URLForResource:@"shared" withExtension:@"cblite"];
        NSURL *sharedTargetURL = [[NSURL fileURLWithPath:sharedPackagePath] URLByAppendingPathComponent:@"shared.cblite"];
        
        if (sharedDBFixture) {
            NSParameterAssert(sharedDBFixture);
            
            NSURL *sharedAttachmentsFixture = [[NSBundle appBundle] URLForResource:@"shared attachments" withExtension:@""];
            NSURL *sharedAttachmentsDirectoryURL = [[NSURL fileURLWithPath:sharedPackagePath] URLByAppendingPathComponent:@"shared attachments"];
            
            if (sharedAttachmentsFixture) {
                NSString *sharedAttachmentsPath = [sharedPackagePath stringByAppendingPathComponent:@"shared attachments"];
                if ([fm fileExistsAtPath:sharedAttachmentsPath])
                    [fm removeItemAtPath:sharedAttachmentsPath error:&err];

                BOOL fixtureCopySuccess = [[NSFileManager defaultManager] copyItemAtURL:sharedDBFixture
                                                                                  toURL:sharedTargetURL
                                                                                  error:&err];
                NSParameterAssert(fixtureCopySuccess);
                
                BOOL fixtureAttachmentCopySuccess = [[NSFileManager defaultManager] copyItemAtURL:sharedAttachmentsFixture
                                                                                            toURL:sharedAttachmentsDirectoryURL
                                                                                            error:&err];
                NSParameterAssert(fixtureAttachmentCopySuccess);
            }
        }

        MPShoeboxPackageController *sharedPackage = [MPShoeboxPackageController sharedShoeboxController];
        XCTAssertTrue(sharedPackage != nil, @"A shared package controller initialized");
        
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
        XCTAssertTrue([fm createDirectoryAtPath:_testPackageRootDirectory withIntermediateDirectories:YES
                                    attributes:nil error:&err],
                     @"Creating document root succeeded.");
    
    XCTAssertTrue(!err, @"No error should happen with creating the package root directory");
}

- (void)createSharedPackageRootDirectory
{
    NSError *err = nil;
    [MPShoeboxPackageController createSharedDatabasesPathWithError:&err];
    XCTAssertTrue(!err, @"No error should happen with creating the shared package root directory");
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
    
    XCTAssertTrue(!err, @"No error occurred loading fixtures from %@", url);
    
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
            
            NSLog(@"Loaded %lu fixture objects from %@", objs.count, url);
            
            if (err) break;
        }
    }
    
    XCTAssertTrue(!err, @"Loading fixtures succeeds.");
}

- (void)tearDown
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (_testPackageRootDirectory && [fm fileExistsAtPath:_testPackageRootDirectory])
    {
        NSError *err = nil;
        XCTAssertTrue([fm removeItemAtPath:_testPackageRootDirectory error:&err], @"Deleting document root succeeded.");
    }
    
#if MP_DEBUG_ZOMBIE_MODELS
    [MPManagedObject clearModelObjectMap];
#endif
    
    [super tearDown];
    
    if ([[MPShoeboxPackageController sharedShoeboxPackageControllerClass] isSubclassOfClass:[MPFeatherTestPackageController class]])
        [MPShoeboxPackageController deregisterShoeboxPackageControllerClass];
}

// test suites which need to act as a MPDatabasePackageControllerDelegate need to overload this.
- (NSURL *)packageRootURL
{
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

@end