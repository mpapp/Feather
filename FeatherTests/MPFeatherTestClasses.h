//
//  MPFeatherTestClasses.h
//  Feather
//
//  Created by Matias Piipari on 06/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Feather.h"

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
