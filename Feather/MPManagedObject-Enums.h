//
//  MPManagedObject-Enums.h
//  Feather
//
//  Created by Matias Piipari on 13/07/2019.
//  Copyright © 2019 Matias Piipari. All rights reserved.
//

#ifndef MPManagedObject_Enums_h
#define MPManagedObject_Enums_h

typedef NS_ENUM(NSInteger, MPManagedObjectErrorCode)
{
    MPManagedObjectErrorCodeUnknown = 0,
    MPManagedObjectErrorCodeTypeMissing = 1,
    MPManagedObjectErrorCodeUserNotCreator = 2,
    MPManagedObjectErrorCodeMissingBundledData = 3,
    MPManagedObjectErrorCodeMissingAttachment = 4,
    MPManagedObjectErrorCodeMissingController = 5,
    MPManagedObjectErrorCodeMissingDatabase = 6
};

typedef NS_ENUM(NSInteger, MPManagedObjectModerationState)
{
    MPManagedObjectModerationStateUnmoderated = 0,
    MPManagedObjectModerationStateAccepted = 1,
    MPManagedObjectModerationStateRejected = 2
};

typedef NS_ENUM(NSInteger, MPManagedObjectChangeSource)
{
    MPManagedObjectChangeSourceInternal = 0,    // internal change (change assumed internal if no source given)
    MPManagedObjectChangeSourceAPI = 1,         // change made in in-process via the RESTful web service API ( touchdb:// or http(s):// )
    MPManagedObjectChangeSourceExternal = 2     // changes coming in from external source ( e.g. replication )
};

#endif /* MPManagedObject_Enums_h */
