//
//  MPModelFoundationTests.m
//  Feather
//
//  Created by Matias Piipari on 06/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPModelFoundationTests.h"
#import "MPFeatherTestClasses.h"

//
// MPManagedObject
// |____MPManagedObjectConcretenessTest
//
// MPTestObject
// |____A
//      |___B
//      |___C
//      |___D__E
//
// Expected: MPTestObject isConcrete    = false
//           A isConcrete               = false
//           B isConcrete               = true
//           C isConcrete               = true
//           D isConcrete               = true (overridden)
//           E isConcrete               = true
//
//           A,B,C,D,E instances all have a MPFeatherTestAsController as their controller.
//
@interface MPFeatherTestA : MPTestObject @end
@implementation MPFeatherTestA
+ (BOOL)isConcrete { return NO; }
@end

@interface MPManagedObjectConcretenessTest : MPManagedObject @end
@implementation MPManagedObjectConcretenessTest @end

@interface MPManagedObjectConcretenessTestsController : MPManagedObjectsController @end
@implementation MPManagedObjectConcretenessTestsController @end

@interface MPFeatherTestAsController : MPManagedObjectsController @end
@implementation MPFeatherTestAsController @end

@interface MPFeatherTestB : MPFeatherTestA
@end

@implementation MPFeatherTestB
+ (BOOL)isConcrete { return YES; }
@end

@interface MPFeatherTestC : MPFeatherTestA @end
@implementation MPFeatherTestC
+ (BOOL)isConcrete { return YES; }
@end

@interface MPFeatherTestD : MPFeatherTestA @end

@implementation MPFeatherTestD
+ (BOOL)isConcrete { return YES; }
@end

@interface MPFeatherTestE : MPFeatherTestD @end
@implementation MPFeatherTestE
+ (BOOL)isConcrete { return YES; }
@end

@implementation MPModelFoundationTests

- (void)testNotifications
{
    NSDictionary *notificationDict = [NSNotificationCenter managedObjectNotificationNameDictionary];
    
    XCTAssertTrue([notificationDict[@(MPChangeTypeAdd)][NSStringFromClass([MPMoreSpecificTestObject class])][@"did"] isEqualToString:@"didAddTestObject"],
                 @"The notification name for MPMoreSpecificTestObject is MPTestObject because \
                 there is a MPTestObjectsController but no MPMoreSpecificTestObjectsController.");
    
    XCTAssertTrue([notificationDict[@(MPChangeTypeUpdate)][NSStringFromClass([MPMoreSpecificTestObject class])][@"has"] isEqualToString:@"hasUpdatedTestObject"],
                 @"The notification name for MPMoreSpecificTestObject is MPTestObject because \
                 there is a MPTestObjectsController but no MPMoreSpecificTestObjectsController.");
}

- (void)testDocumentIDAfterDeletion {
    
    MPFeatherTestPackageController *tpkg = [MPFeatherTestPackageController sharedPackageController];
    MPTestObjectsController *ac = tpkg.testObjectsController;
    MPTestObject *obj = [[MPFeatherTestE alloc] initWithNewDocumentForController:ac];
    
    XCTAssertTrue([obj save], @"Saving object should have succeeded: %@", obj);
    XCTAssertTrue([obj deleteDocument], @"Deleting object should have succeeded: %@", obj);
    XCTAssertTrue([obj documentID], @"Object should still have a documentID after deletion: %@", obj);
}

- (void)testHumanReadableName {
    MPFeatherTestPackageController *tpkg = [MPFeatherTestPackageController sharedPackageController];
    MPTestObjectsController *ac = tpkg.testObjectsController;
    MPTestObject *obj = [[MPFeatherTestE alloc] initWithNewDocumentForController:ac];

    XCTAssertTrue([obj save], @"Save unexpectedly failed.");
    
    XCTAssertTrue([obj.documentID hasPrefix:@"MPFeatherTestE:"]);
    XCTAssertTrue(![obj.prefixlessDocumentID hasPrefix:@"MPFeatherTestE:"]);
    
    XCTAssertTrue([obj.class humanReadableName], @"FeatherTestE");
}

- (void)testDictionaryRepresentations {
    MPFeatherTestPackageController *tpkg = [MPFeatherTestPackageController sharedPackageController];
    MPTestObjectsController *ac = tpkg.testObjectsController;
    MPTestObject *obj = [[MPFeatherTestE alloc] initWithNewDocumentForController:ac];
    
    XCTAssertTrue([obj save], @"Save unexpectedly failed.");
    
    XCTAssertTrue([[[obj propertiesToSave] managedObjectType] isEqualToString:@"MPFeatherTestE"]);
    XCTAssertTrue([[[obj propertiesToSave] managedObjectDocumentID] isEqualToString:obj.documentID]);
    XCTAssertTrue([[[obj propertiesToSave] managedObjectRevisionID] isEqualToString:obj.document.currentRevisionID]);
}

- (void)testConcreteness
{
    MPFeatherTestPackageController *tpkg = [MPFeatherTestPackageController sharedPackageController];
    MPTestObjectsController *ac = tpkg.testObjectsController;
    
    
    MPTestObject *a, *b, *c, *d, *e;
    
    XCTAssertTrue(![MPManagedObject isConcrete], @"MPManagedObject is not concrete");
    XCTAssertTrue([MPManagedObjectConcretenessTest isConcrete], @"MPManagedObjectConcretenessTest is concrete");
    
    XCTAssertTrue(![MPFeatherTestA isConcrete], @"A is not concrete");
    XCTAssertTrue([MPFeatherTestB isConcrete], @"B is concrete");
    XCTAssertTrue([MPFeatherTestC isConcrete], @"C is concrete");
    XCTAssertTrue([MPFeatherTestD isConcrete], @"D is concrete");
    XCTAssertTrue([MPFeatherTestE isConcrete], @"E is concrete");

    XCTAssertThrows(a = [[MPFeatherTestA alloc] initWithNewDocumentForController:ac], @"A cannot be instantiated");
    XCTAssertNoThrow(b = [[MPFeatherTestB alloc] initWithNewDocumentForController:ac], @"B can be instantiated");
    XCTAssertNoThrow(c = [[MPFeatherTestC alloc] initWithNewDocumentForController:ac], @"C can be instantiated");
    XCTAssertNoThrow(d = [[MPFeatherTestD alloc] initWithNewDocumentForController:ac], @"D can be instantiated");
    XCTAssertNoThrow(e = [[MPFeatherTestE alloc] initWithNewDocumentForController:ac], @"E can be instantiated");
}

@end
