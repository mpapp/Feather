//
//  MPSnapshotsController.h
//  Feather
//
//  Created by Matias Piipari on 03/10/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPManagedObjectsController.h"

@class MPSnapshot, MPSnapshottedObject;
@class MPSnapshottedObject, MPSnapshottedAttachment;

/** A MPSnapshotsController manages MPSnapshot objects: allows creating snapshots, and returning snapshotted data associated with a snapshot. Read more about snapshots from the (Snapshot programming guide)[docs/snapshots.html]. */
@interface MPSnapshotsController : MPManagedObjectsController

/** Create a new named snapshot. The snapshot object is given in a block to give an illusion of a 'transaction':  it clear it's only to be appended to inside of this block and should be treated immutable outside of it.
 @param name The name for the section. Must be non-nil but not necessarily unique.
 @param snapshotHandler snapshotHandler A block in which objects are to be added to the snapshot. */
- (void)newSnapshotWithName:(NSString *)name snapshotHandler:(void (^)(MPSnapshot *docList, NSError *err))snapshotHandler;

/** Returns a snapshotted object, which itself wraps metadata for a managed object in one of the databases from the same database package as the snapshot.
 * @param obj The object for which to return snapshotted data. Must belong to the same database package as the snapshot (2nd argument).
 * @param snapshot The snapshot for which to return snapshotted data of the managed object. Must belong to the same database package as the managed object (1st argument).  */
- (MPSnapshottedObject *)snapshotOfObject:(MPManagedObject *)obj forSnapshot:(MPSnapshot *)snapshot;

/** Returns snapshotted objects belonging to a snapshot.
 * @param snapshot A snapshot for which to return snapshotted objects.
 */
- (NSArray *)snapshottedObjectsForSnapshot:(MPSnapshot *)snapshot;

/** Returns a snapshotted attachment for a SHA1 checksum. 
  * @param sha SHA1 checksum for which to get snapshotted attachments for. */
- (MPSnapshottedAttachment *)snapshottedAttachmentForSHA:(NSString *)sha;

/** Returns snapshotted attachments for a snapshot.
  * @param snapshot MPSnapshot instance for which to get snapshotted attachments for. */
- (NSArray *)snapshottedAttachmentsForSnapshot:(MPSnapshot *)snapshot;

@end