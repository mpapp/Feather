//
//  MPExtensionTests.m
//  Manuscripts
//
//  Created by Matias Piipari on 13/02/2013.
//  Copyright (c) 2013 Manuscripts.app Limited. All rights reserved.
//

#import "MPExtensionTests.h"
#import "MPContributorsController.h"
#import "MPContributor.h"
#import "MPSnapshot.h"
#import "MPCacheable.h"

#import <Feather/MPManagedObject.h>
#import <Feather/MPException.h>
#import <Feather/NSObject+MPExtensions.h>

@implementation MPExtensionTests

- (void)testCommonAncestry
{
    STAssertTrue([NSObject commonAncestorForClass:[NSObject class] andClass:[NSObject class]]
                  == [NSObject class],
                 @"NSObject's common ancestor with NSObject should be NSObject.");
    
    STAssertTrue([NSObject commonAncestorForClass:[MPContributor class] andClass:[MPManagedObject class]]
                 == [MPManagedObject class],
                 @"MPContributor's common ancestor with MPManagedObject should be MPManagedObject.");
    
    STAssertTrue([NSObject commonAncestorForClass:[MPSnapshot class] andClass:[MPManagedObject class]]
                 == [MPManagedObject class],
                 @"MPStyle's common ancestor with MPManagedObject should be MPManagedObject.");
}

- (void)testPropertyKeys
{
    /*
    MPManuscriptsPackageController *packageController = [[MPManuscriptsPackageController alloc] initWithPath:self.docRoot delegate:self error:&err];
    STAssertTrue(packageController != nil, @"Document database controller was initialised");
    
    MPSharedPackageController *spc = [MPSharedPackageController sharedPackageController];
    MPManuscriptCategoriesController *cc = [spc manuscriptCategoriesController];
    
    MPManuscriptCategory *category = [[MPManuscriptCategory alloc] initWithController:cc identifier:nil name:@"Foo" desc:@"bar" imageNamed:nil];
    */
    
    NSSet *propertyKeys = [MPContributorsController propertyKeys];
    STAssertTrue([[MPContributorsController propertyKeys]
                   containsObject:@"cachedContributors"],
                 @"There should be a property 'cachedContributors'");
    STAssertTrue([propertyKeys containsObject:@"allObjects"],
                 @"There should be a property 'allObjects'");
    STAssertTrue([propertyKeys containsObject:@"allContributors"],
                 @"There should be a property 'allContributors'");
    STAssertTrue([propertyKeys containsObject:@"allAuthors"],
                 @"There should be a property 'allAuthors'");
    STAssertTrue([propertyKeys containsObject:@"allEditors"],
                 @"There should be a property 'allEditors'");
    STAssertTrue([propertyKeys containsObject:@"allTranslators"],
                 @"There should be a property 'allTranslators'");
    
    NSDictionary *dict = [MPContributorsController cachedPropertiesByClassName];
    STAssertTrue(dict[NSStringFromClass([MPContributorsController class])] != nil,
                 @"There should be a record of 'MPSharedManuscriptCategoriesController'");
    
    //[[category save] wait];
}

@end
