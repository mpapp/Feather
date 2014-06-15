//
//  MPEmbeddedObjectsTests.m
//  Feather
//
//  Created by Matias Piipari on 04/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "FeatherTests.h"
#import "MPFeatherTestClasses.h"

#import "MPEmbeddedObjectsTests.h"

#import <Feather/MPEmbeddedObject+Protected.h>

@implementation MPEmbeddedObjectsTests

- (void)setUp
{
    [MPShoeboxPackageController deregisterShoeboxPackageControllerClass];
    [MPShoeboxPackageController registerShoeboxPackageControllerClass:[MPFeatherTestPackageController class]];
}

- (void)tearDown
{
    [MPShoeboxPackageController deregisterShoeboxPackageControllerClass];
}

- (void)testEmbeddedObjectCreation
{
    MPFeatherTestPackageController *tpkg = [MPFeatherTestPackageController sharedPackageController];
    MPTestObjectsController *tc = tpkg.testObjectsController;
    
    MPTestObject *obj = [[MPTestObject alloc] initWithNewDocumentForController:tc];
    
    obj.title = @"foo";
    obj.desc = @"bar";
    obj.contents = @"foobar";
    
    obj.embeddedTestObject = [[MPEmbeddedTestObject alloc] initWithEmbeddingObject:obj embeddingKey:@"embeddedTestObject"];
    NSLog(@"%@", [obj propertiesToSave]);
    
    mp_dispatch_sync(obj.database.manager.dispatchQueue, [obj.controller.packageController serverQueueToken], ^{
        XCTAssertTrue(!obj.document.properties[@"embeddedTestObject"],
                      @"The property value is cached in the properties dictionary.");
        
        XCTAssertTrue(!obj.document.properties[@"embeddedTestObject"],
                      @"The property value is not present in the model object's properties dictionary before saving.");
        
        XCTAssertTrue([obj getValueOfProperty:@"embeddedTestObject"],
                      @"The property value is available via -getValueOfProperty: before saving.");
        
        XCTAssertTrue([[obj getValueOfProperty:@"embeddedTestObject"] isKindOfClass:[MPEmbeddedTestObject class]],
                      @"The property value is of the expected MPEmbeddedTestObject class.");
        
        XCTAssertTrue(obj.needsSave, @"Embedding object should be marked needing save.");
        XCTAssertTrue(obj.embeddedTestObject, @"Embedded object should be marked needing save.");
        
        XCTAssertTrue([obj.embeddedTestObject save:nil], @"Setting the embedded object succeeds.");
        
        XCTAssertTrue(!obj.embeddedTestObject.needsSave,
                      @"Embedded object doesn't need saving after saving.");
        XCTAssertTrue(!obj.embeddedTestObject.embeddingObject.needsSave,
                      @"Embedded object's embedding object doesn't need saving after saving.");
        
        XCTAssertTrue([obj.document.properties[@"embeddedTestObject"] isKindOfClass:NSString.class],
                      @"The interal, persisted property value is a string.");
        
        XCTAssertTrue([[obj getValueOfProperty:@"embeddedTestObject"] isKindOfClass:MPEmbeddedTestObject.class],
                      @"The property value fetched for property 'embeddedTestObject' is a MPEmbeddedTestObject instance.");
        
        
        obj.embeddedTestObject.aStringTypedProperty = @"foobar";
        
        XCTAssertTrue(obj.embeddedTestObject.needsSave,
                      @"Embedded object need saving after 'aStringTypedProperty' has changed.");
        XCTAssertTrue(obj.embeddedTestObject.embeddingObject.needsSave,
                      @"Embedded object's embedding object needs saving after the embedded object's 'aStringTypedProperty' has changed.");
        
        XCTAssertTrue([obj.embeddedTestObject.properties[@"aStringTypedProperty"] isEqualToString:@"foobar"],
                      @"Properties dictionary contains the correct string object.");
        
        XCTAssertTrue([obj.embeddedTestObject.aStringTypedProperty isEqualToString:@"foobar"],
                      @"Property getter retrieves the object.");
        
        
        obj.embeddedTestObject.anUnsignedIntTypedProperty = 12;
        
        XCTAssertTrue(obj.embeddedTestObject.anUnsignedIntTypedProperty == 12,
                      @"Integral getter retrieves the right value.");
        
        XCTAssertTrue(obj.embeddedTestObject.properties[@"aStringTypedProperty"] != nil,
                      @"aStringTypedProperty is present in the embedded object's properties.");
        
        NSError *err = nil;
        XCTAssertTrue([obj.embeddedTestObject save:&err], @"Embedded object saving succeeds.");
        
        XCTAssertTrue(!obj.embeddedTestObject.needsSave, @"Managed object property value has been set and object doesn't need saving.");
        obj.embeddedTestObject.embeddedManagedObjectProperty = obj;
        XCTAssertTrue(obj.embeddedTestObject.needsSave, @"Managed object property value has been set and object needs saving.");
        
        XCTAssertTrue([obj.embeddedTestObject save:&err], @"Embedded object saving succeeds.");
        
        XCTAssertTrue(!obj.needsSave, @"Managed object property value has been set and embedding object no longer needs saving.");
        XCTAssertTrue(!obj.embeddedTestObject.needsSave, @"Managed object property value has been set and object no longer needs saving.");
        
        XCTAssertTrue(obj.embeddedTestObject.embeddedManagedObjectProperty == obj, @"The embedded managed property has the expected value.");
        
        MPEmbeddedTestObject *foo = [[MPEmbeddedTestObject alloc] initWithEmbeddingObject:obj.embeddedTestObject embeddingKey:@"embeddedArrayOfTestObjects"];
        
        obj.embeddedTestObject.embeddedArrayOfTestObjects = @[ foo ];
        
        XCTAssertTrue([obj needsSave], @"Object needs saving again");
        XCTAssertTrue([obj.embeddedTestObject needsSave], @"Object needs saving again");
        
        XCTAssertTrue([[[obj embeddedTestObject] embeddedArrayOfTestObjects] containsObject:foo], @"Array contains the expected object");
        XCTAssertTrue([[[obj embeddedTestObject] embeddedArrayOfTestObjects] count] == 1, @"Array contains only the expected object");
        
        XCTAssertTrue([obj save:nil], @"Saving the object succeeds.");
        
        NSLog(@"Object: %@", [[obj embeddedTestObject] embeddedArrayOfTestObjects]);
        
        XCTAssertTrue(![obj needsSave], @"Object no longer needs saving");
        XCTAssertTrue(![obj.embeddedTestObject needsSave], @"Object no longer needs saving");
        
        XCTAssertTrue([obj deleteDocument:nil], @"Deleting the document succeeds");
    });
}

@end
