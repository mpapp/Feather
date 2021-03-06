//
//  MPFeatherTestClasses.m
//  Feather
//
//  Created by Matias Piipari on 06/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPFeatherTestClasses.h"

@import Feather.MPDatabasePackageController_Protected;

@implementation MPFeatherTestPackageController {
    NSUUID *_uuid;
}

+ (void)load
{
    if (![MPShoeboxPackageController sharedShoeboxPackageControllerClass])
    {
        [self registerShoeboxPackageControllerClass:self];
    }
}

- (instancetype)initWithError:(NSError *__autoreleasing *)err
{
    if (self = [super initWithError:err])
    {
        _testObjectsController =
            [[MPTestObjectsController alloc] initWithPackageController:self database:self.primaryDatabase error:err];
        if (!_testObjectsController)
            return nil;
    }
    
    return self;
}

+ (instancetype)sharedPackageController
{
    MPFeatherTestPackageController *tpc = [MPFeatherTestPackageController sharedShoeboxController];
    assert([tpc isKindOfClass:[MPFeatherTestPackageController class]]);
    return tpc;
}

- (BOOL)indexesObjectFullTextContents { return YES; }

+ (NSString *)primaryDatabaseName { return @"shared"; }

- (NSString *)identifier {
    if (!_uuid) {
        _uuid = [NSUUID UUID];
    }
    
    return _uuid.UUIDString;
}

@end

@implementation MPTestObject
@dynamic embeddedTestObject;
@dynamic title, subtitle, desc, contents;

+ (NSArray *)indexablePropertyKeys {
    return @[ @"title", @"desc", @"contents" ];
}

+ (BOOL)isConcrete
{
    return YES;
}

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
