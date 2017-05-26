//
//  FeatherTests.h
//  FeatherTests
//
//  Created by Matias Piipari on 29/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Feather;
@import Foundation;
@import XCTest;

@class MPDatabasePackageController;
@class MPManagedObject;

@interface FeatherTests : XCTestCase <MPDatabasePackageControllerDelegate>

/** A root path for a package controllers initialised for a test. Automatically created and deleted by the test suite in setup and teardown. */
@property (copy, nonnull) NSString *testPackageRootDirectory;

@property (readonly, copy, nonnull) NSString *bundleLoaderName;

/** A utility method for loading bundled fixture objects from a JSON file of a given managed object type for a package controller. */
- (nonnull NSArray<MPManagedObject *> *)loadFixturesForManagedObjectClass:(nonnull Class)cls
                                                      toPackageController:(nonnull MPDatabasePackageController *)pkgc
                                                         fromJSONResource:(nonnull NSString *)resource;

@end
