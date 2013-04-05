//
//  FeatherTests.h
//  FeatherTests
//
//  Created by Matias Piipari on 29/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "Feather.h"

@interface MPFeatherTestSuite : SenTestCase <MPDatabasePackageControllerDelegate>
@property (copy) NSString *docRoot;
@end

@class MPEmbeddedTestObject;

@interface MPTestObject : MPManagedObject

@property (readwrite, strong) MPEmbeddedTestObject *embeddedTestObject;

@end

@interface MPEmbeddedTestObject : MPEmbeddedObject
@property (strong) MPEmbeddedTestObject *anotherEmbeddedObject;

@property (readwrite, copy) NSString *aStringTypedProperty;
@property (readwrite, assign) NSUInteger anUnsignedIntTypedProperty;
@end

@interface MPTestObjectsController : MPManagedObjectsController
@end



@class MPTestObject, MPEmbeddedTestObject, MPTestObjectsController;

@interface MPFeatherTestPackageController : MPShoeboxPackageController
+ (instancetype)sharedPackageController;

@property (readonly, strong) MPTestObjectsController *testObjectsController;
@end
