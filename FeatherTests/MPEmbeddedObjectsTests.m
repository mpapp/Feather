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
    
    obj.embeddedTestObject = [[MPEmbeddedTestObject alloc] initWithEmbeddingObject:obj];
    NSLog(@"%@", [obj propertiesToSave]);
    NSLog(@"%@", obj.document.properties);

    STAssertTrue(!obj.document.properties[@"embeddedTestObject"],
                 @"The property value is cached in the properties dictionary.");
    
    STAssertTrue(!obj.document.properties[@"embeddedTestObject"],
                 @"The property value is not present in the model object's properties dictionary before saving.");
    
    STAssertTrue([obj getValueOfProperty:@"embeddedTestObject"],
                 @"The property value is available via -getValueOfProperty: before saving.");
    
    STAssertTrue([[obj getValueOfProperty:@"embeddedTestObject"] isKindOfClass:[MPEmbeddedTestObject class]],
                 @"The property value is of the expected MPEmbeddedTestObject class.");
    
    STAssertTrue(obj.needsSave, @"Embedding object should be marked needing save.");
    STAssertTrue(obj.embeddedTestObject, @"Embedded object should be marked needing save.");
    
    id<MPWaitingOperation> saveOp = [obj.embeddedTestObject save];
    STAssertTrue([saveOp wait], @"Setting the embedded object succeeds.");
    
    STAssertTrue([obj.document.properties[@"embeddedTestObject"] isKindOfClass:NSString.class],
                 @"The interal, persisted property value is a string.");
    
    STAssertTrue([[obj getValueOfProperty:@"embeddedTestObject"] isKindOfClass:MPEmbeddedTestObject.class],
                 @"The property value fetched for property 'embeddedTestObject' is a MPEmbeddedTestObject instance.");
}

@end
