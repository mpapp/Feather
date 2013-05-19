//
//  MPDatabasePackageController+Protected.h
//  Feather
//
//  Created by Matias Piipari on 23/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPDatabasePackageController.h"
#import "MPManagedObject.h"

@class CouchDocument;

@interface MPDatabasePackageController (Protected)

- (void)registerManagedObjectsController:(MPManagedObjectsController *)moc;

@property (strong, readwrite) NSMutableArray *pulls;
@property (strong, readwrite) NSMutableArray *completedPulls;
@property (strong, readwrite) MPPullCompletionHandler pullCompletionHandler;

@property (strong, readwrite) MPDatabase *primaryDatabase;

/** Abstract method which is to be overloaded in subclasses of MPDatabasePackageController 
  * that use the database listener. */
- (void)didStartDatabaseListener;

- (void)makeNotificationCenter;

- (void)didChangeDocument:(CouchDocument *)document source:(MPManagedObjectChangeSource)source;

@end