//
//  MPContributorsController.h
//  Feather
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPManagedObjectsController.h"
#import "NSNotificationCenter+MPManagedObjectExtensions.h"

extern NSString *_Nonnull const MPContributorRoleAuthor;
extern NSString *_Nonnull const MPContributorRoleEditor;
extern NSString *_Nonnull const MPContributorRoleTranslator;

@class MPContributor, MPContributorIdentity;

/** Have classes which observe MPContributor changes conform to this protocol. That is, a class X whose instances x are sent
 
 [[packageController notificationCenter] addObserver:x forManagedObjectClass:[MPContributor class]]
 
 should conform to this protocol.
 */
@protocol MPContributorChangeObserver <MPManagedObjectChangeObserver, NSObject>
- (void)didAddContributor:(nonnull NSNotification *)notification;
- (void)didUpdateContributor:(nonnull NSNotification *)notification;
- (void)didRemoveContributor:(nonnull NSNotification *)notification;
@end

@protocol MPContributorRecentChangeObserver <MPManagedObjectRecentChangeObserver, NSObject>
- (void)hasAddedContributor:(nonnull NSNotification *)notification;
- (void)hasUpdatedContributor:(nonnull NSNotification *)notification;
- (void)hasRemovedContributor:(nonnull NSNotification *)notification;
@end


/** Controller for MPContributor objects. */
@interface MPContributorsController : MPManagedObjectsController <MPContributorRecentChangeObserver, MPCacheable>

/** An MPContributor object that signifies the current user. Created on demand. */
@property (readonly, strong, nonnull) MPContributor *me;

/** An MPContributor object that signifies the current user. */
@property (readonly, strong, nullable) MPContributor *existingMe;

/** All contributors available in the managed objects controller's database. */
@property (strong, readonly, nonnull) NSArray<MPContributor *> *allContributors;

@property (readonly, strong, nonnull) NSArray<MPContributor *> *allAuthors;
@property (readonly, strong, nonnull) NSArray<MPContributor *> *allEditors;
@property (readonly, strong, nonnull) NSArray<MPContributor *> *allTranslators;

/** A comparator block which is used to sort comparators in your application specific natural sort order. 
  * No default is given, and the block must be set to a non-nil value before any fetch methods are called.
  * Can be set to a non-nil value only once. */
@property (readwrite, strong, nonatomic, nonnull) NSComparator contributorComparator;

/** Contributor with the given address book ID. A contributor has more than one address book IDs (each author may have an author in their own address book), 
  * but each of those IDs should be globally unique. */
- (nullable MPContributor *)contributorWithAddressBookID:(nonnull NSString *)personUniqueID;

/** Contributors with the given full name. 'fullName' is a derived property of a MPContributor but it is updated every time the primary 'nameString' field is updated. */
- (nonnull NSArray<MPContributor *>*)contributorsWithFullName:(nonnull NSString *)fullName;

typedef void (^MPContributorPriorityChangeHandler)(MPContributor *_Nonnull c, NSUInteger oldIndex, NSUInteger newIndex);

/** Refreshes the priorities of the contributors 
  * such that it matches the index of the contributor in the array. */
+ (NSUInteger)refreshPrioritiesForContributors:(nonnull NSArray<MPContributor *>*)contributors
                           changedContributors:(NSArray *_Nullable *_Nullable)changedContributors;

+ (void)moveContributors:(nonnull NSArray *)contributors
     amongstContributors:(nonnull NSArray *)universeOfContributors
                 toIndex:(NSUInteger)index
      indexChangeHandler:(__nullable MPContributorPriorityChangeHandler)handler;

@end


#pragma mark -

@interface MPContributorIdentitiesController : MPManagedObjectsController

- (nonnull NSArray *)contributorIdentitiesForContributor:(nonnull MPContributor *)contributor;
- (nonnull NSArray *)contributorIdentitiesWithIdentifier:(nonnull NSString *)identifier;
- (nonnull NSArray *)contributorsWithContributorIdentifier:(nonnull NSString *)identifier;
- (nonnull NSArray *)contributorsWithContributorIdentity:(nonnull MPContributorIdentity *)identity;

@end