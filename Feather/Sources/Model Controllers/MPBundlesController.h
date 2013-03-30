//
//  MPBundlesController.h
//  Manuscripts
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
//

#import "MPManagedObjectsController.h"
#import "MPBundle.h"

/** Abstract base class for MPBundle object controllers. */
@interface MPBundlesController : MPManagedObjectsController <MPBundleRecentChangeObserver>

@property (readonly, strong) NSArray *allFields;
@property (readonly, strong) NSArray *allLicenses;

- (NSDictionary *)mapBundlesByField:(NSArray *)bundles fieldSet:(NSSet *)fields;

@end