//
//  MPFeatherTestClasses.h
//  Feather
//
//  Created by Matias Piipari on 06/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Feather/Feather.h>
#import <Feather/MPTitledProtocol.h>

@class MPEmbeddedTestObject;

@interface MPTestObject : MPManagedObject <MPTitledProtocol>

@property (readwrite, strong) MPEmbeddedTestObject *embeddedTestObject;

@property (readwrite, copy) NSString *title;
@property (readwrite, copy) NSString *desc;
@property (readwrite, copy) NSString *contents;

@end

/* Used to test the model => model controller, model => notification mapping. */
@interface MPMoreSpecificTestObject : MPTestObject
@end

@interface MPEmbeddedTestObject : MPEmbeddedObject
@property (strong) MPEmbeddedTestObject *anotherEmbeddedObject;

@property (readwrite, copy) NSString *aStringTypedProperty;
@property (readwrite, assign) NSUInteger anUnsignedIntTypedProperty;

@property (readwrite, strong) MPTestObject *embeddedManagedObjectProperty;

@property (readwrite, strong) NSArray *embeddedArrayOfTestObjects;
@property (readwrite, strong) NSDictionary *embeddedDictionaryOfTestObjects;

@end

@interface MPTestObjectsController : MPManagedObjectsController
@end



@class MPTestObject, MPEmbeddedTestObject, MPTestObjectsController;

@interface MPFeatherTestPackageController : MPShoeboxPackageController
+ (instancetype)sharedPackageController;

@property (readonly, strong) MPTestObjectsController *testObjectsController;
@end
