//
//  MPContributorsController.h
//  Feather
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPManagedObjectsController.h"
#import "NSNotificationCenter+MPExtensions.h"

extern NSString * const MPContributorRoleAuthor;
extern NSString * const MPContributorRoleEditor;
extern NSString * const MPContributorRoleTranslator;

@class MPContributor, MPContributorIdentity;

/** Have classes which observe MPContributor changes conform to this protocol. That is, a class X whose instances x are sent
 
 [[packageController notificationCenter] addObserver:x forManagedObjectClass:[MPContributor class]]
 
 should conform to this protocol.
 */
@protocol MPContributorChangeObserver <MPManagedObjectChangeObserver, NSObject>
- (void)didAddContributor:(NSNotification *)notification;
- (void)didUpdateContributor:(NSNotification *)notification;
- (void)didRemoveContributor:(NSNotification *)notification;
@end

@protocol MPContributorRecentChangeObserver <MPManagedObjectRecentChangeObserver, NSObject>
- (void)hasAddedContributor:(NSNotification *)notification;
- (void)hasUpdatedContributor:(NSNotification *)notification;
- (void)hasRemovedContributor:(NSNotification *)notification;
@end


/** Controller for MPContributor objects. */
@interface MPContributorsController : MPManagedObjectsController <MPContributorRecentChangeObserver, MPCacheable>

/** An MPContributor object that signifies the current user. Created on demand. */
@property (readonly, strong) MPContributor *me;

/** An MPContributor object that signifies the current user. */
@property (readonly, strong) MPContributor *existingMe;

/** All contributors available in the managed objects controller's database. */
@property (strong, readonly) NSArray *allContributors;

@property (readonly, strong) NSArray *allAuthors;
@property (readonly, strong) NSArray *allEditors;
@property (readonly, strong) NSArray *allTranslators;

/** A comparator block which is used to sort comparators in your application specific natural sort order. 
  * No default is given, and the block must be set to a non-nil value before any fetch methods are called.
  * Can be set to a non-nil value only once. */
@property (readwrite, strong, nonatomic) NSComparator contributorComparator;

/** Contributor with the given address book ID. A contributor has more than one address book IDs (each author may have an author in their own address book), 
  * but each of those IDs should be globally unique. */
- (MPContributor *)contributorWithAddressBookID:(NSString *)personUniqueID __attribute__((nonnull));

/** Contributors with the given full name. 'fullName' is a derived property of a MPContributor but it is updated every time the primary 'nameString' field is updated. */
- (NSArray *)contributorsWithFullName:(NSString *)fullName __attribute__((nonnull));

typedef void (^MPContributorPriorityChangeHandler)(MPContributor *c, NSUInteger oldIndex, NSUInteger newIndex);

/** Refreshes the priorities of the contributors 
  * such that it matches the index of the contributor in the array. */
+ (NSUInteger)refreshPrioritiesForContributors:(NSArray *)contributors
                           changedContributors:(NSArray **)changedContributors;

+ (void)moveContributors:(NSArray *)contributors
     amongstContributors:(NSArray *)universeOfContributors
                 toIndex:(NSUInteger)index
      indexChangeHandler:(MPContributorPriorityChangeHandler)handler;

@end


#pragma mark -

@interface MPContributorIdentitiesController : MPManagedObjectsController

- (NSArray *)contributorIdentitiesForContributor:(MPContributor *)contributor;
- (NSArray *)contributorIdentitiesWithIdentifier:(NSString *)identifier __attribute__((nonnull));
- (NSArray *)contributorsWithContributorIdentifier:(NSString *)identifier __attribute__((nonnull));
- (NSArray *)contributorsWithContributorIdentity:(MPContributorIdentity *)identity __attribute__((nonnull));

@end