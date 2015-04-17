//
//  MPContributor.h
//  Feather
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPManagedObject.h"
#import "MPTreeItem.h"
#import <Feather/MPPlaceHolding.h>

@class MPContributorCategory;

/** A contributor (author) model object class, managed by a MPContributorsController. Setting any of the readwrite properties can change one of the other readwrite or readonly properties, so take care to observe changes by observing changes to authors with a MPContributorChangeObserver conforming object when presenting the state of MPContributor objects. */
@interface MPContributor : MPManagedObject <MPPlaceHolding>

@property (readwrite) MPContributorCategory *category;
@property (readwrite, strong) NSString *role;

/** A database package should contain at most one MPContributor object which is considered to be 'me' for a user editing the document.
 @return Returns YES if user matches the current user, NO otherwise. */
@property BOOL isMe;

@property BOOL isCorresponding;

/** The priority of the author in the author list. 
  * Joint authorship priorities are legal (for instance joint 1st authorship). */
@property (readonly) NSInteger priority;

/** Description of the contributor's contributions. */
@property (readwrite) NSString *contribution;

- (NSComparisonResult)compare:(MPContributor *)contributor;

#ifndef MPAPP
@property (readwrite, copy) NSString *fullName;
#endif

@end
