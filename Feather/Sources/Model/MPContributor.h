//
//  MPContributor.h
//  Feather
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPManagedObject.h"
#import "MPTreeItem.h"
#import "MPPlaceHolding.h"

@class MPContributorCategory;

/** A contributor (author) model object class, managed by a MPContributorsController. Setting any of the readwrite properties can change one of the other readwrite or readonly properties, so take care to observe changes by observing changes to authors with a MPContributorChangeObserver conforming object when presenting the state of MPContributor objects. */
@interface MPContributor : MPManagedObject <MPMutablyPlaceHolding>

@property (readwrite) MPContributorCategory *category;
@property (readwrite, strong) NSString *role;

/** A database package should contain at most one MPContributor object which is considered to be 'me' for a user editing the document on any given device.
 @return Returns YES if user matches the current user on the current device, NO otherwise. */
@property (readwrite) BOOL isMe;

/** The priority of the author in the author list. 
  * Joint authorships are legal but not expressed with an equal priority. */
@property (readonly) NSInteger priority;

/** Priority incremented with 1 such that counting begins from 1 and values smaller than that are trimmed to it. */
@property (readonly) NSInteger positiveIntegralPriority;

/** Description of the contributor's contributions. */
@property (readwrite) NSString *contribution;

/** An array of ABPerson uniqueIds for the contributor. 
  * Different authors may have different address book IDs to refer to the same record. */
@property (readwrite) NSArray *addressBookIDs;

@property (readonly) NSImage *thumbnailImage;

/** An array of MPContributorIdentity objects for the contributor. Mutate it by adding / removing MPContributorIdentity objects. */
@property (readonly) NSArray *identities;

/** Date when the contributor in question has been last invited to use the app. */
@property (readwrite) NSDate *appInvitationDate;

/** YES if the contributor is first amongst sorted contributors to the manuscript.
  * Only ever applies to one contributor, even if there are joint authorships. */
@property (readonly) BOOL isFirstContributor;

/** YES if the contributor is last amongst sorted contributors to the manuscript.
 * Only ever applies to one contributor, even if there are joint authorships. */
@property (readonly) BOOL isLastContributor;

/** Previous contributor according to the priorities set for the contributors. */
@property (readonly) MPContributor *previousContributor;

/** Next contributor according to the priorities set for the contributors. */
@property (readonly) MPContributor *nextContributor;


- (NSComparisonResult)compare:(MPContributor *)contributor;

#ifndef MPAPP
@property (readwrite, copy) NSString *fullName;
#endif

@end

#pragma mark -

/** A contributor identity maps a contributor to an identifier of some kind. */
@interface MPContributorIdentity : MPManagedObject

/** The contributor should be set only once. */
@property (readwrite, nonatomic) MPContributor *contributor;

/** The contributor should be set only once. */
@property (readwrite, nonatomic) NSString *identifier;

/** The contributor should be set only once. */
@property (readwrite, nonatomic) NSString *namespace;

@end
