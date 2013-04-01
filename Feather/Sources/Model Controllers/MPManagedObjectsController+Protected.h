//
//  MPManagedObjectsController+Protected.h
//  Feather
//
//  Created by Matias Piipari on 23/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPManagedObjectsController.h"

@class CouchDocument;

@interface MPManagedObjectsController (Protected)

- (void)willSaveObject:(MPManagedObject *)object;
- (void)didSaveObject:(MPManagedObject *)object;

- (void)didUpdateObject:(MPManagedObject *)object;

- (void)willDeleteObject:(MPManagedObject *)object;
- (void)didDeleteObject:(MPManagedObject *)object;

- (void)didChangeDocument:(CouchDocument *)document forObject:(MPManagedObject *)object;
- (void)didLoadObjectFromDocument:(MPManagedObject *)object;

- (void)registerObject:(MPManagedObject *)mo;
- (void)deregisterObject:(MPManagedObject *)mo;

@property (readonly, strong) dispatch_queue_t queryQueue;

@end
