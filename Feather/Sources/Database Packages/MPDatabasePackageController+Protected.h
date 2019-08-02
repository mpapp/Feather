//
//  MPDatabasePackageController+Protected.h
//  Feather
//
//  Created by Matias Piipari on 23/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPDatabasePackageController.h"
#import "MPManagedObject.h"

@class CBLDocument;

@interface MPDatabasePackageController (Protected)

- (void)registerManagedObjectsController:(MPManagedObjectsController *)moc;

@property (strong, readwrite) NSMutableArray *pulls;
@property (strong, readwrite) NSMutableArray *completedPulls;
@property (strong, readwrite) MPPullCompletionHandler pullCompletionHandler;

- (void)registerViewName:(NSString *)viewName;

@property (strong, readwrite) MPDatabase *primaryDatabase;

/** Abstract method which is to be overloaded in subclasses of MPDatabasePackageController 
  * that use the database listener. */
- (void)didStartPackageListener;

- (void)makeNotificationCenter;

- (void)didChangeDocument:(CBLDocument *)document source:(MPManagedObjectChangeSource)source;

/** Override in subclass if you want to use multiple CBLManagers in the database package. */
- (CBLManager *)serverForDatabaseWithName:(NSString *)dbName;

+ (NSMapTable *)databasePackageControllerRegistry;

@end
