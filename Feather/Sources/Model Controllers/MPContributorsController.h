//
//  MPContributorsController.h
//  Manuscripts
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
//

#import "MPManagedObjectsController.h"
#import "NSNotificationCenter+MPExtensions.h"

extern NSString * const MPContributorRoleAuthor;
extern NSString * const MPContributorRoleEditor;
extern NSString * const MPContributorRoleTranslator;

@class MPContributor;

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
@interface MPContributorsController : MPManagedObjectsController <MPContributorRecentChangeObserver>

/** An MPContributor object that signifies the current user. Created on demand. */
@property (readonly, strong) MPContributor *me;

/** All contributors available in the managed objects controller's database. */
@property (strong, readonly) NSArray *allContributors;

@property (readonly, strong) NSArray *allAuthors;
@property (readonly, strong) NSArray *allEditors;
@property (readonly, strong) NSArray *allTranslators;

@end