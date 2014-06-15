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
+ (BOOL)isConcrete {
    return NO;
}
@end

@interface MPFeatherTestAsController : MPManagedObjectsController @end
@implementation MPFeatherTestAsController @end

@interface MPFeatherTestB : MPFeatherTestA @end
@implementation MPFeatherTestB @end

@interface MPFeatherTestC : MPFeatherTestA @end
@implementation MPFeatherTestC @end

@interface MPFeatherTestD : MPFeatherTestA @end

@implementation MPFeatherTestD
+ (BOOL)isConcrete {
    return YES;
}
@end

@interface MPFeatherTestE : MPFeatherTestD @end
@implementation MPFeatherTestE @end

@implementation MPModelFoundationTests

- (void)setUp
{
    [MPShoeboxPackageController deregisterShoeboxPackageControllerClass];
    [MPShoeboxPackageController registerShoeboxPackageControllerClass:[MPFeatherTestPackageController class]];
}

- (void)tearDown
{
    [MPShoeboxPackageController deregisterShoeboxPackageControllerClass];
}

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

- (void)testConcreteness
{
    MPFeatherTestPackageController *tpkg = [MPFeatherTestPackageController sharedPackageController];
    MPTestObjectsController *ac = tpkg.testObjectsController;
    
    MPTestObject *a, *b, *c, *d, *e;
    
    XCTAssertTrue(![MPFeatherTestA isConcrete], @"A is not concrete");
    XCTAssertTrue([MPFeatherTestB isConcrete], @"B is concrete");
    XCTAssertTrue(![MPFeatherTestC isConcrete], @"C is concrete");
    XCTAssertTrue(![MPFeatherTestD isConcrete], @"D is concrete");
    XCTAssertTrue(![MPFeatherTestE isConcrete], @"E is concrete");

    XCTAssertThrows(a = [[MPFeatherTestA alloc] initWithNewDocumentForController:ac], @"A cannot be instantiated");
    XCTAssertNoThrow(b = [[MPFeatherTestB alloc] initWithNewDocumentForController:ac], @"B can be instantiated");
    XCTAssertNoThrow(c = [[MPFeatherTestC alloc] initWithNewDocumentForController:ac], @"C can be instantiated");
    XCTAssertNoThrow(d = [[MPFeatherTestD alloc] initWithNewDocumentForController:ac], @"D can be instantiated");
    XCTAssertNoThrow(e = [[MPFeatherTestE alloc] initWithNewDocumentForController:ac], @"E can be instantiated");
}

@end