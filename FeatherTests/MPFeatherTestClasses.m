//
//  MPFeatherTestClasses.m
//  Feather
//
//  Created by Matias Piipari on 06/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPFeatherTestClasses.h"
#import "MPDatabasePackageController+Protected.h"

@implementation MPFeatherTestPackageController

+ (void)initialize
{
    if (self == [MPFeatherTestPackageController class])
    {
        [self registerShoeboxPackageControllerClass:self];
    }
}

- (instancetype)initWithError:(NSError *__autoreleasing *)err
{
    if (self = [super initWithError:err])
    {
        _testObjectsController =
        [[MPTestObjectsController alloc] initWithPackageController:self database:self.primaryDatabase];
    }
    
    return self;
}

+ (instancetype)sharedPackageController
{
    MPFeatherTestPackageController *tpc = [MPFeatherTestPackageController sharedShoeboxController];
    assert([tpc isKindOfClass:[MPFeatherTestPackageController class]]);
    return tpc;
}

+ (NSString *)primaryDatabaseName { return @"shared"; }

@end

@implementation MPTestObject
@dynamic embeddedTestObject;
@end

@implementation MPMoreSpecificTestObject
@end

@implementation MPEmbeddedTestObject
@dynamic anotherEmbeddedObject;
@dynamic aStringTypedProperty;
@dynamic anUnsignedIntTypedProperty;
@dynamic embeddedManagedObjectProperty;
@dynamic embeddedArrayOfTestObjects;
@dynamic embeddedDictionaryOfTestObjects;
@end

@implementation MPTestObjectsController
@end