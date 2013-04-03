//
//  MPSharedPackageController.h
//  Feather
//
//  Created by Matias Piipari on 12/10/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPDatabasePackageController.h"
#import "NSNotificationCenter+MPExtensions.h"

extern NSString * const MPGlobalUserDatabaseIdentifier;
extern NSString * const MPDefaultsKeySharedPackageUDID;

/** An abstract base class for database package controller which manages crowd sourced objects pulled from a remote server and bundled with the application. Snapshotting is not supported by the shared package controller. Shared database package is not synchronized peerlessly. */
@interface MPShoeboxPackageController : MPDatabasePackageController <MPManagedObjectSharingObserver>

#ifdef MP_UNIT_TEST
+ (BOOL)sharedPackageControllerInitialized;
+ (void)finalizeSharedPackageController;
#endif

+ (BOOL)createSharedDatabasesPathWithError:(NSError **)err;

- (instancetype)initWithError:(NSError *__autoreleasing *)err;

/** Signifies whether user data is synchronized with user's own remote database. Default implementation always returns YES. */
@property (readonly) BOOL synchronizesUserData;

/** Signifies whether user data is synchronized with a global remote database. Default implementation always returns YES. */
@property (readonly) BOOL sharesUserData;

/** A globally unique identifier for the shared package. For now, stored in user defaults so can get lost. */
+ (NSString *)udid;

/** Initializes application support data if it's missing. */
- (void)initializeApplicationSupportData;

/** Name of the remote database this shoebox synchronizes with. */
@property (readonly, copy) NSString *remoteGlobalSharedDatabaseName;

/** Base URL to the remote global database this shoebox synchronizes with. */
@property (readonly, copy) NSURL *remoteGlobalSharedDatabaseURL;

/** Register the subclass of MPShoeboxPackageController used by this application. Should be called exactly once in the +initialize of the subclass, with itself given as the argument. */
+ (void)registerShoeboxPackageControllerClass:(Class)class;

/** The base directory for the shoebox's data. */
+ (NSString *)sharedDatabasesPath;

+ (instancetype)sharedShoeboxController;

@end