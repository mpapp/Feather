//
//  MPEmbeddedObjectsTests.m
//  Feather
//
//  Created by Matias Piipari on 04/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "FeatherTests.h"
#import "MPEmbeddedObjectsTests.h"

@implementation MPEmbeddedObjectsTests

- (void)testEmbeddedObjectCreation
{
    MPFeatherTestPackageController *tpkg = [MPFeatherTestPackageController sharedPackageController];
    MPTestObjectsController *tc = tpkg.testObjectsController;
    
    MPTestObject *obj = [[MPTestObject alloc] initWithNewDocumentForController:tc];
    MPEmbeddedTestObject *eobj = [[MPEmbeddedTestObject alloc] initWithEmbeddingObject:obj];
}

@end
