//
//  MPEmbeddedObjectsTests.m
//  Feather
//
//  Created by Matias Piipari on 04/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPFeatherTestSuite.h"
#import "MPFeatherTestClasses.h"

#import "MPEmbeddedObjectsTests.h"
#import "MPEmbeddedObject+Protected.h"

#import "MPSearchIndexController.h"

@implementation MPEmbeddedObjectsTests

- (void)testEmbeddedObjectCreation
{
    MPFeatherTestPackageController *tpkg = [MPFeatherTestPackageController sharedPackageController];
    MPTestObjectsController *tc = tpkg.testObjectsController;
    
    MPTestObject *obj = [[MPTestObject alloc] initWithNewDocumentForController:tc];
    
    obj.title = @"foo";
    obj.desc = @"bar";
    obj.contents = @"foobar";
    
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
    
    STAssertTrue(!obj.embeddedTestObject.needsSave,
                 @"Embedded object doesn't need saving after saving.");
    STAssertTrue(!obj.embeddedTestObject.embeddingObject.needsSave,
                 @"Embedded object's embedding object doesn't need saving after saving.");
    
    STAssertTrue([obj.document.properties[@"embeddedTestObject"] isKindOfClass:NSString.class],
                 @"The interal, persisted property value is a string.");
    
    STAssertTrue([[obj getValueOfProperty:@"embeddedTestObject"] isKindOfClass:MPEmbeddedTestObject.class],
                 @"The property value fetched for property 'embeddedTestObject' is a MPEmbeddedTestObject instance.");
    
    
    obj.embeddedTestObject.aStringTypedProperty = @"foobar";
    
    STAssertTrue(obj.embeddedTestObject.needsSave,
                 @"Embedded object need saving after 'aStringTypedProperty' has changed.");
    STAssertTrue(obj.embeddedTestObject.embeddingObject.needsSave,
                 @"Embedded object's embedding object needs saving after the embedded object's 'aStringTypedProperty' has changed.");
    
    STAssertTrue([obj.embeddedTestObject.properties[@"aStringTypedProperty"] isEqualToString:@"foobar"],
                 @"Properties dictionary contains the correct string object.");
    
    STAssertTrue([obj.embeddedTestObject.aStringTypedProperty isEqualToString:@"foobar"],
                 @"Property getter retrieves the object.");
    
    
    obj.embeddedTestObject.anUnsignedIntTypedProperty = 12;
    
    STAssertTrue(obj.embeddedTestObject.anUnsignedIntTypedProperty == 12,
                 @"Integral getter retrieves the right value.");
    
    STAssertTrue(obj.embeddedTestObject.properties[@"aStringTypedProperty"] != nil,
                 @"aStringTypedProperty is present in the embedded object's properties.");
    
    [[obj.embeddedTestObject save] wait];

    STAssertTrue(!obj.embeddedTestObject.needsSave, @"Managed object property value has been set and object doesn't need saving.");
    obj.embeddedTestObject.embeddedManagedObjectProperty = obj;
    STAssertTrue(obj.embeddedTestObject.needsSave, @"Managed object property value has been set and object needs saving.");
    
    [[obj.embeddedTestObject save] wait];

    STAssertTrue(!obj.needsSave, @"Managed object property value has been set and embedding object no longer needs saving.");
    STAssertTrue(!obj.embeddedTestObject.needsSave, @"Managed object property value has been set and object no longer needs saving.");

    STAssertTrue(obj.embeddedTestObject.embeddedManagedObjectProperty == obj, @"The embedded managed property has the expected value.");
    
    MPEmbeddedTestObject *foo = [[MPEmbeddedTestObject alloc] initWithEmbeddingObject:obj.embeddedTestObject];
    
    obj.embeddedTestObject.embeddedArrayOfTestObjects = @[ foo ];
    
    STAssertTrue([obj needsSave], @"Object needs saving again");
    STAssertTrue([obj.embeddedTestObject needsSave], @"Object needs saving again");
    
    STAssertTrue([[[obj embeddedTestObject] embeddedArrayOfTestObjects] containsObject:foo], @"Array contains the expected object");
    STAssertTrue([[[obj embeddedTestObject] embeddedArrayOfTestObjects] count] == 1, @"Array contains only the expected object");
    
    [[obj save] wait];
    
    NSLog(@"Object: %@", [[obj embeddedTestObject] embeddedArrayOfTestObjects]);
    
    STAssertTrue(![obj needsSave], @"Object no longer needs saving");
    STAssertTrue(![obj.embeddedTestObject needsSave], @"Object no longer needs saving");

    NSArray *objsByTitle = [tpkg.searchIndexController objectsWithMatchingTitle:@"foo"];
    STAssertTrue(objsByTitle.count == 1, @"There are objects in the search index with matching");
    
    NSArray *objsByDesc = [tpkg.searchIndexController objectsWithMatchingDesc:@"bar"];
    STAssertTrue(objsByDesc.count == 1, @"There are objects in the search index with matching");
    
    [[obj deleteDocument] wait];
    
    objsByTitle = [tpkg.searchIndexController objectsWithMatchingTitle:@"foo"];
    STAssertTrue(objsByTitle.count == 0, @"There should be no objects in the search index with matching title any longer");
    
    objsByDesc = [tpkg.searchIndexController objectsWithMatchingDesc:@"bar"];
    STAssertTrue(objsByDesc.count == 0, @"There should be no objects in the search index with matching desc any longer");
    
}

@end
