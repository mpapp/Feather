//
//  MPSnapshot.h
//  Feather
//
//  Created by Matias Piipari on 03/10/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPManagedObject.h"

@class MPSnapshotsController, CBLAttachment;

/** A MPSnapshot is an object which contains metadata about a snapshot. MPSnapshot instances are not to be created directly, but via the MPSnapshotsController. */
@interface MPSnapshot : MPManagedObject

/** A human readable name for the snapshot. */
@property (readonly, strong) NSString *name;

/** A timestamp for the moment the snapshot was created. Not the exact time the snapshot creation was registered, but the time soon before it was sent for saving to the database. */
@property (readonly, strong) NSDate *timestamp;
@end

/** MPSnapshottedObject instances contain serialised data of other managed objects from the same database package as where it is stored. */
@interface MPSnapshottedObject : MPManagedObject

/** The identifier of the snapshot this MPSnapshottedObject belongs to.  */
@property (readonly, copy) NSString *snapshotID;

/** The snapshot which this MPSnapshottedObject is contained in. */
@property (readonly, weak) MPSnapshot *snapshot;

/** The document ID of the managed object snapshotted in this object. */
@property (readonly, strong) NSString *snapshottedDocumentID;

/** The revision ID of the managed object snapshotted in this object. */
@property (readonly, strong) NSString *snapshottedRevisionID;

/** The properties snapshotted for a managed object in this object. */
@property (readonly, strong) NSDictionary *snapshottedProperties;

/** An array of snapshot object SHAs */
@property (readonly, strong) NSArray *snapshottedAttachmentSHAs;

/** An array of MPSnapshottedAttachment objects */
@property (readonly, strong) NSArray *snapshottedAttachments;

/** */

/** The class of the managed object which is snapshotted in this object. Must be a subclass of MPManagedObject. */
@property (readonly, strong) Class snapshottedObjectClass;
@end

/** An object used as a container for attachments in a snapshot database. MPSnapshottedObject instances do not have associated attachments, but  */
@interface MPSnapshottedAttachment : MPManagedObject

/** Creates a new snapshotted attachment for a snapshot controller's database using the data and content type of a CBLAttachment.
  * @param controller A MPSnapshotsController whose database this snapshot is saved to. Must be non-nil.
  * @param attachment A CBLAttachment from which the data and the content type is retrieved from. Must be non-nil.
  * @param err An optional error pointer.
 */
- (instancetype)initWithSnapshotsController:(MPSnapshotsController *)controller
                       attachment:(CBLAttachment *)attachment
                                      error:(NSError **)err;

/** The SHA1 checksum of the attachment data. */
@property (readonly, copy) NSString *sha;

/** The content type of the attachment data. */
@property (readonly, copy) NSString *contentType;

/** A getter for the attachment data associated with this object. */
@property (readonly, strong) CBLAttachment *attachment;

/** The identifier of the snapshot this MPSnapshottedObject belongs to.  */
@property (readonly, copy) NSString *snapshotID;

/** The snapshot which this MPSnapshottedObject is contained in. */
@property (readonly, weak) MPSnapshot *snapshot;

@end