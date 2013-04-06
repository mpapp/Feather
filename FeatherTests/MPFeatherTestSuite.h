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

/** A root path for a package controllers initialised for a test. Automatically created and deleted by the test suite in setup and teardown. */
@property (copy) NSString *testPackageRootDirectory;

@end