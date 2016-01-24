//
//  MPExtensionTests.m
//  Manuscripts
//
//  Created by Matias Piipari on 13/02/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPExtensionTests.h"

@import Feather;
@import FeatherExtensions;

#import <objc/runtime.h>

@interface MPSwizzlingTestObject : NSObject
- (BOOL)exampleMethod:(BOOL)boolArgument;
@end

@implementation MPSwizzlingTestObject
- (BOOL)exampleMethod:(BOOL)boolArgument
{
    return boolArgument;
}
@end

@implementation MPExtensionTests

- (void)testCommonAncestry
{
    XCTAssertTrue([NSObject commonAncestorForClass:[NSObject class] andClass:[NSObject class]]
                  == [NSObject class],
                 @"NSObject's common ancestor with NSObject should be NSObject.");
    
    XCTAssertTrue([NSObject commonAncestorForClass:[MPContributor class] andClass:[MPManagedObject class]]
                 == [MPManagedObject class],
                 @"MPContributor's common ancestor with MPManagedObject should be MPManagedObject.");
    
    XCTAssertTrue([NSObject commonAncestorForClass:[MPSnapshot class] andClass:[MPManagedObject class]]
                 == [MPManagedObject class],
                 @"MPStyle's common ancestor with MPManagedObject should be MPManagedObject.");
}

- (void)testPropertyKeys
{
    /*
    MPManuscriptsPackageController *packageController = [[MPManuscriptsPackageController alloc] initWithPath:self.testPackageRootDirectory delegate:self error:&err];
    XCTAssertTrue(packageController != nil, @"Document database controller was initialised");
    
    MPSharedPackageController *spc = [MPSharedPackageController sharedPackageController];
    MPManuscriptCategoriesController *cc = [spc manuscriptCategoriesController];
    
    MPManuscriptCategory *category = [[MPManuscriptCategory alloc] initWithController:cc identifier:nil name:@"Foo" desc:@"bar" imageNamed:nil];
    */
    
    NSSet *propertyKeys = [MPContributorsController propertyKeys];
    XCTAssertTrue([[MPContributorsController propertyKeys]
                   containsObject:@"cachedContributors"],
                 @"There should be a property 'cachedContributors'");
    XCTAssertTrue([propertyKeys containsObject:@"allObjects"],
                 @"There should be a property 'allObjects'");
    XCTAssertTrue([propertyKeys containsObject:@"allContributors"],
                 @"There should be a property 'allContributors'");
    XCTAssertTrue([propertyKeys containsObject:@"allAuthors"],
                 @"There should be a property 'allAuthors'");
    XCTAssertTrue([propertyKeys containsObject:@"allEditors"],
                 @"There should be a property 'allEditors'");
    XCTAssertTrue([propertyKeys containsObject:@"allTranslators"],
                 @"There should be a property 'allTranslators'");
    
    NSDictionary *dict = [MPManagedObjectsController cachedPropertiesByClassName];
    XCTAssertTrue(dict[NSStringFromClass([MPContributorsController class])] != nil,
                 @"There should be a record of 'MPSharedManuscriptCategoriesController'");
    
    //[[category save] wait];
}

- (void)testBundleExtensions {
    XCTAssertTrue([NSBundle inTestSuite], @"Correctly detected as being in a test suite.");
}

- (void)testSwizzling
{
    MPSwizzlingTestObject *obj = [[MPSwizzlingTestObject alloc] init];
    XCTAssertTrue([obj exampleMethod:YES],  @"Before swizzling should return YES when argument is YES");
    XCTAssertFalse([obj exampleMethod:NO],  @"Before swizzling should return NO when argument is NO");
    
    [MPSwizzlingTestObject replaceInstanceMethodWithSelector:@selector(exampleMethod:)
                                 implementationBlockProvider:^id(IMP originalImplementation) {
        return ^(MPSwizzlingTestObject* receiver, BOOL boolArgument) {
            BOOL origValue = originalImplementation(receiver, @selector(exampleMethod:), boolArgument);
            BOOL retVal = !origValue;
            return retVal;
        };
    }];
    
    XCTAssertFalse([obj exampleMethod:YES], @"After swizzling should return NO when argument is YES");
    XCTAssertTrue([obj exampleMethod:NO],   @"After swizzling should return YES when argument is NO");
}

@end
