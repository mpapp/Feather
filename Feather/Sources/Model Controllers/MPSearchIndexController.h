//
//  MPSearchIndexController.h
//  Feather
//
//  Created by Matias Piipari on 07/05/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSNotificationCenter+MPExtensions.h"

extern NSString * const MPSearchIndexControllerErrorDomain;

typedef NS_ENUM(NSInteger, MPSearchIndexControllerErrorCode) {
    MPSearchIndexControllerErrorCodeUnknown = 0,
    MPSearchIndexControllerErrorCodeOpenFailed = 1,
    MPSearchIndexControllerErrorCodeVirtualTableCreationFailed = 2,
    MPSearchIndexControllerErrorCodeIndexingObjectFailed = 3,
    MPSearchIndexControllerErrorCodeReindexingObjectFailed = 4,
    MPSearchIndexControllerErrorCodeDeletionFromIndexFailed = 5
};

@class MPDatabasePackageController;

@interface MPSearchIndexController : NSObject <MPManagedObjectRecentChangeObserver>

@property (readonly, weak) MPDatabasePackageController *packageController;

@property (readonly, strong) NSError *lastError;

- (instancetype)initWithPackageController:(MPDatabasePackageController *)packageController;

- (BOOL)ensureCreatedWithError:(NSError **)err;
- (void)indexManagedObjects:(NSArray *)objects error:(NSError **)err;
- (BOOL)indexManagedObject:(MPManagedObject *)object error:(NSError **)err;

- (NSArray *)objectsWithMatchingTitle:(NSString *)title;
- (NSArray *)objectsWithMatchingDesc:(NSString *)desc;
- (NSArray *)objectsWithMatchingContents:(NSString *)contents;
- (NSArray *)objectsMatchingQuery:(NSString *)query;

- (NSArray *)objectsOfManagedObjectClass:(Class)class withMatchingTitle:(NSString *)title;
- (NSArray *)objectsOfManagedObjectClass:(Class)class withMatchingDesc:(NSString *)desc;
- (NSArray *)objectsOfManagedObjectClass:(Class)class withMatchingContents:(NSString *)desc;
- (NSArray *)objectsOfManagedObjectClass:(Class)class matchingQuery:(NSString *)query;

@end