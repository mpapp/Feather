//
//  MPSnapshot+MPSnapshot_Protected.h
//  Feather
//
//  Created by Matias Piipari on 03/10/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPSnapshot.h"

/** An additional interface for MPSnapshot intended to be used by MPSnapshotsController. */
@interface MPSnapshot (Protected)
- (MPSnapshot *)initWithController:(MPSnapshotsController *)packageController name:(NSString *)name;
@end

/** An additional interface for MPSnapshottedObject intended to be used by MPSnapshotsController. */
@interface MPSnapshottedObject (Protected)

+ (NSString *)idForSnapshottedObjectWithDocumentID:(NSString *)documentID
                                        revisionID:(NSString *)revisionID
                                        inDatabase:(CouchDatabase *)db;

- (MPSnapshottedObject *)initWithController:(MPSnapshotsController *)sc
                                   snapshot:(MPSnapshot *)snapshot
                          snapshottedObject:(MPManagedObject *)obj;

@end