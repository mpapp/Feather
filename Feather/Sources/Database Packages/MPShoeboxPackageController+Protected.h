//
//  MPShoeboxPackageController_Protected.h
//  Feather
//
//  Created by Matias Piipari on 03/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Feather/Feather.h>

@interface MPShoeboxPackageController ()
{
    MPDatabase *_sharedDatabase;
    MPDatabase *_globalSharedDatabase;
}

@property (readwrite, strong) MPDatabase *sharedDatabase;
@property (readwrite, strong) MPDatabase *globalSharedDatabase;
@property (readwrite, strong) CouchServer *globalSharedDatabaseServer;

@end
