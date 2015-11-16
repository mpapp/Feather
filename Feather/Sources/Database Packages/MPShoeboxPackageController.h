//
//  MPSharedPackageController.h
//  Feather
//
//  Created by Matias Piipari on 12/10/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPDatabasePackageController.h"
#import "NSNotificationCenter+MPManagedObjectExtensions.h"

extern NSString * const MPGlobalUserDatabaseIdentifier;
extern NSString * const MPDefaultsKeySharedPackageUDID;

/** An abstract base class for database package controller which manages crowd sourced objects pulled from a remote server and bundled with the application. Snapshotting is not supported by the shared package controller. Shared database package is not synchronized peerlessly. */
@interface MPShoeboxPackageController : MPDatabasePackageController <MPManagedObjectSharingObserver>

// used for unit testing

/** override in subclass to act in this (quite likely critical) scenario. */
+ (void)sharedShoeboxControllerFailedToInitialize;

+ (BOOL)sharedShoeboxControllerInitialized;

+ (void)finalizeSharedShoeboxController;

+ (BOOL)createSharedDatabasesPathWithError:(NSError **)err;

- (instancetype)initWithError:(NSError *__autoreleasing *)err;

/** Signifies whether user data is synchronized with user's own remote database. Default implementation always returns YES. */
@property (readonly) BOOL synchronizesUserData;

/** Signifies whether user data is synchronized with a global remote database. Default implementation always returns YES. */
@property (readonly) BOOL sharesUserData;

/** A globally unique identifier for the shared package. For now, stored in user defaults so can get lost. */
+ (NSString *)udid;

/** Initializes application support data if it's missing. */
- (void)initializeBundledData;

/** Name of the remote database this shoebox synchronizes with. */
@property (readonly, copy) NSString *remoteGlobalSharedDatabaseName;

/** Base URL to the remote global database this shoebox synchronizes with. */
@property (readonly, copy) NSURL *remoteGlobalSharedDatabaseURL;

/** Register the subclass of MPShoeboxPackageController used by this application. Should be called exactly once in the +initialize of the subclass, with itself given as the argument. */
+ (void)registerShoeboxPackageControllerClass:(Class)class;

+ (void)deregisterShoeboxPackageControllerClass;

/** The currently registered shared shoebox package controller class. */
+ (Class)sharedShoeboxPackageControllerClass;

/** An optional name given for the shoebox, used to place the shoebox data under Application Support under this name instead of the default behaviour of placing it under a directory named after app bundle. */
+ (NSString *)name;

/** The base directory for the shoebox's data. */
+ (NSString *)sharedDatabasesPath;

+ (instancetype)sharedShoeboxController;

@end