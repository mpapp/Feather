//
//  NSBundle+Feather.h
//  Feather
//
//  Created by Matias Piipari on 17/11/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Foundation;

@interface NSBundle (Feather)

@property (readonly, copy, nonnull) NSString *bundleNameString;

@property (readonly, copy, nonnull) NSString *bundleShortVersionString;
@property (readonly, copy, nonnull) NSString *bundleVersionString;

@property (readonly) BOOL isSandboxed;

/** Returns the main bundle for non-unit test targets, and the unit test bundle for the unit tests. */
+ (nonnull NSBundle *)appBundle;

+ (nullable NSBundle *)XPCServiceBundleWithName:(nonnull NSString *)name;

/** Find out if bundles are loaded by a test suite.
 *  @return YES if bundle loader is a test suite runner, NO otherwise. */
+ (BOOL)inTestSuite;

+ (BOOL)isCommandLineTool;
+ (BOOL)isXPCService;

@end
