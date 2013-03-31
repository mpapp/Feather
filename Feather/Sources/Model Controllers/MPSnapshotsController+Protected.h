//
//  MPSnapshotsController+Protected.h
//  Manuscripts
//
//  Created by Matias Piipari on 03/10/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
//

#import "MPSnapshotsController.h"

@class MPSnapshottedObjectsController, MPSnapshottedAttachmentsController;

@interface MPSnapshotsController (Protected)

/** The controller of MPSnapshottedObject instances for this MPSnapshotsController's database. */
@property (readonly, strong) MPSnapshottedObjectsController *snapshottedObjectsController;

/** The controller of MPSnapshottedAttachment instances for this MPSnapshotsController's database.  */
@property (readonly, strong) MPSnapshottedAttachmentsController *snapshottedAttachmentsController;
@end


#pragma mark -

/** A MPSnapshottedObjectsController manages MPSnapshottedObject instances. MPSnapshottedObjectsControllers are not intended to be instantiated manully, but are used internally in the MPSnapshotsControllers to manage snapshotted objects. */
@interface MPSnapshottedObjectsController : MPManagedObjectsController

/** A weak back pointer to this controller's snapshots controller (always non-nil). */
@property (readonly, weak) MPSnapshotsController *snapshotsController;

- (instancetype)initWithSnapshotsController:(MPSnapshotsController *)controller;

/** Returns the snapshotted objects for a snapshot.
  * @param snapshot The snapshot for which to return snapshotted objects for. */
- (NSArray *)snapshottedObjectsForSnapshot:(MPSnapshot *)snapshot;

@end


#pragma mark -

/** A MPSnapshottedAttachmentsController manages MPSnapshottedAttachment instances. MPSnapshottedAttachmentsController instances are not to be instantiated manually, but are used internally by MPSnapshotsControllers to manage snapshotted attachments. */
@interface MPSnapshottedAttachmentsController : MPManagedObjectsController

/** A weak back pointer to this controller's snapshots controller (always non-nil). */
@property (readonly, weak) MPSnapshotsController *snapshotsController;

- (instancetype)initWithSnapshotsController:(MPSnapshotsController *)controller;

/** Returns the snapshotted attachments for a snapshot. 
  * @param snapshot The snapshot for which to return snapshotted objects for. */
- (NSArray *)snapshottedAttachmentsForSnapshot:(MPSnapshot *)snapshot;

/** Returns a snapshotted attachment for a SHA1 checksum.
  * @param sha The SHA1 checksum string to return a MPSnapshottedAttachment for */
- (MPSnapshottedAttachment *)snapshottedAttachmentForSHA:(NSString *)sha;

@end