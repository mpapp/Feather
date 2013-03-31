//
//  MPSnapshotsController.m
//  Manuscripts
//
//  Created by Matias Piipari on 03/10/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
//

#import "MPSnapshotsController.h"
#import "MPSnapshot+Protected.h"
#import "MPSnapshotsController+Protected.h"
#import "MPManagedObjectsController+Protected.h"

#import "MPDatabase.h"

#import "NSArray+MPExtensions.h"

#import <CouchCocoa/CouchCocoa.h>
#import <TouchDB/TouchDB.h>

@class MPSnapshottedObjectsController;
@class MPSnapshottedAttachment, MPSnapshottedAttachmentsController;

@interface MPSnapshotsController ()
@property (readonly, strong) MPSnapshottedObjectsController *snapshottedObjectsController;
@property (readonly, strong) MPSnapshottedAttachmentsController *snapshottedAttachmentsController;
@end

@implementation MPSnapshotsController

- (instancetype)initWithPackageController:(MPDatabasePackageController *)packageController database:(MPDatabase *)db
{
    if (self = [super initWithPackageController:packageController database:db])
    {
        _snapshottedObjectsController
            = [[MPSnapshottedObjectsController alloc] initWithPackageController:packageController database:db];
        _snapshottedAttachmentsController
            = [[MPSnapshottedAttachmentsController alloc] initWithPackageController:packageController database:db];
    }
    
    return self;
}

+ (Class)managedObjectClass
{
    return [MPSnapshot class];
}

- (void)newSnapshotWithName:(NSString *)name snapshotHandler:(void (^)(MPSnapshot *snapshot))snapshotHandler
{
    MPSnapshot *snapshot = [[MPSnapshot alloc] initWithController:self name:name];
    [snapshot save];
    snapshotHandler(snapshot);
}

- (MPSnapshottedObject *)snapshotOfObject:(MPManagedObject *)obj forSnapshot:(MPSnapshot *)snapshot
{
    assert([obj isKindOfClass:[MPManagedObject class]]);
    assert([obj isKindOfClass:[MPSnapshot class]]);
    assert(![self.db.database documentWithID:[MPSnapshottedObject idForSnapshottedObjectWithDocumentID:obj.document.documentID
                                                                                    revisionID:obj.document.currentRevisionID inDatabase:self.db.database]]);
    
    MPSnapshottedObject *sobj = [[MPSnapshottedObject alloc] initWithController:self snapshot:snapshot snapshottedObject:obj];
    return sobj;
}

- (void)configureDesignDocument:(CouchDesignDocument *)designDoc
{
    [super configureDesignDocument:designDoc];
}

- (NSArray *)snapshottedObjectsForSnapshot:(MPSnapshot *)snapshot
{
    assert(_snapshottedObjectsController);
    return [self.snapshottedObjectsController snapshottedObjectsForSnapshot:snapshot];
}

- (MPSnapshottedAttachment *)snapshottedAttachmentForSHA:(NSString *)sha
{
    assert(_snapshottedAttachmentsController);
    return [self.snapshottedAttachmentsController snapshottedAttachmentForSHA:sha];
}

- (NSArray *)snapshottedAttachmentsForSnapshot:(MPSnapshot *)snapshot
{
    assert(_snapshottedAttachmentsController);
    return [self.snapshottedAttachmentsController snapshottedAttachmentsForSnapshot:snapshot];
}

@end

@implementation MPSnapshottedObjectsController

- (instancetype)initWithSnapshotsController:(MPSnapshotsController *)controller
{
    if (self = [super initWithPackageController:controller.packageController database:controller.db])
    {
        _snapshotsController = controller;
    }
    
    return self;
}

- (void)configureDesignDocument:(CouchDesignDocument *)designDoc
{
    [super configureDesignDocument:designDoc];
    
    [designDoc defineViewNamed:@"snapshottedObjectsBySnapshotID" mapBlock:^(NSDictionary *doc, TDMapEmitBlock emit) {
        
        if ([doc[@"objectType"] isEqualToString:@"MPSnapshottedObject"])
            emit(doc[@"snapshotID"], nil);
    } version:@"1.0"];
}

- (CouchQuery *)snapshottedObjectsQueryForSnapshot:(MPSnapshot *)snapshot
{
    CouchQuery *q = [self.designDocument queryViewNamed:@"snapshottedObjectsBySnapshotID"];
    q.prefetch = YES;
    return q;
}

- (NSArray *)snapshottedObjectsForSnapshot:(MPSnapshot *)snapshot
{
    return [self managedObjectsForQueryEnumerator:[[self snapshottedObjectsQueryForSnapshot:snapshot] rows]];
}

@end


#pragma mark -

@implementation MPSnapshottedAttachmentsController

- (instancetype)initWithSnapshotsController:(MPSnapshotsController *)controller
{
    if (self = [super initWithPackageController:controller.packageController database:controller.db])
    {
        _snapshotsController = controller;
    }
    
    return self;
}

- (void)configureDesignDocument:(CouchDesignDocument *)designDoc
{
    [super configureDesignDocument:designDoc];
    
    [designDoc defineViewNamed:@"snapshottedAttachmentsBySnapshotID" mapBlock:^(NSDictionary *doc, TDMapEmitBlock emit)
    {
        if ([doc[@"objectType"] isEqualToString:@"MPSnapshottedAttachment"])
            emit(doc[@"snapshotID"], nil);
    } version:@"1.0"];
    
    [designDoc defineViewNamed:@"snapshottedAttachmentsBySHA"  mapBlock:^(NSDictionary *doc, TDMapEmitBlock emit)
    {
        if ([doc[@"objectType"] isEqualToString:@"MPSnapshottedAttachment"])
            emit(doc[@"sha"], nil);
    } version:@"1.0"];
}

- (CouchQuery *)snapshottedAttachmentsQueryForSnapshot:(MPSnapshot *)snapshot
{
    CouchQuery *q = [self.designDocument queryViewNamed:@"snapshottedAttachmentsBySnapshotID"];
    q.prefetch = YES;
    return q;
}

- (NSArray *)snapshottedAttachmentsForSnapshot:(MPSnapshot *)snapshot
{
    return [self managedObjectsForQueryEnumerator:[[self snapshottedAttachmentsQueryForSnapshot:snapshot] rows]];
}

- (CouchQuery *)snapshottedAttachmentsQueryForSHA:(NSString *)sha
{
    CouchQuery *q = [self.designDocument queryViewNamed:@"snapshottedAttachmentsBySHA"];
    q.prefetch = YES;
    q.key = sha;
    return q;
}

- (MPSnapshottedAttachment *)snapshottedAttachmentForSHA:(NSString *)sha
{
    NSArray *attachmentsForSHA = [self managedObjectsForQueryEnumerator:[[self snapshottedAttachmentsQueryForSHA:sha] rows]];
    assert(attachmentsForSHA.count <= 1); // TODO: Handle syncing conflict? More than one can be harmless, one of the objects needs deleting. Which one of multiples is deleted makes no difference
    return [attachmentsForSHA firstObject];
}

@end