//
//  MPSnapshotsController.m
//  Feather
//
//  Created by Matias Piipari on 03/10/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPSnapshotsController.h"
#import "MPSnapshot+Protected.h"
#import "MPDatabase.h"

#import <MPSnapshotsController+Protected.h>
#import <MPManagedObjectsController+Protected.h>

@import FeatherExtensions;
@import CouchbaseLite;

@class MPSnapshottedObjectsController;
@class MPSnapshottedAttachment, MPSnapshottedAttachmentsController;

@interface MPSnapshotsController ()
@property (readonly, strong) MPSnapshottedObjectsController *snapshottedObjectsController;
@property (readonly, strong) MPSnapshottedAttachmentsController *snapshottedAttachmentsController;
@end

@implementation MPSnapshotsController

- (instancetype)initWithPackageController:(MPDatabasePackageController *)packageController
                                 database:(MPDatabase *)db
                                    error:(NSError *__autoreleasing *)err
{
    if (self = [super initWithPackageController:packageController database:db error:err])
    {
        _snapshottedObjectsController
            = [[MPSnapshottedObjectsController alloc] initWithPackageController:packageController database:db error:err];
        
        _snapshottedAttachmentsController
            = [[MPSnapshottedAttachmentsController alloc] initWithPackageController:packageController database:db error:err];
    }
    
    return self;
}

+ (Class)managedObjectClass
{
    return [MPSnapshot class];
}

- (void)newSnapshotWithName:(NSString *)name
            snapshotHandler:(void (^)(MPSnapshot *snapshot, NSError *err))snapshotHandler
{
    NSError *e = nil;
    MPSnapshot *snapshot = [[MPSnapshot alloc] initWithController:self name:name];
    if (![snapshot save:&e])
    {
        assert(e);
        snapshotHandler(nil, e);
    }
    else
    {
        assert(!e);
        snapshotHandler(snapshot, nil);
    }
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

- (void)configureViews
{
    [super configureViews];
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
                                      error:(NSError **)err
{
    if (self = [super initWithPackageController:controller.packageController database:controller.db error:err])
    {
        _snapshotsController = controller;
    }
    
    return self;
}

- (void)configureViews
{
    [super configureViews];
    
    [self viewNamed:@"snapshottedObjectsBySnapshotID" setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit)
     {
         if ([doc[@"objectType"] isEqualToString:@"MPSnapshottedObject"])
             emit(doc[@"snapshotID"], nil);
     } version:@"1.0"];
}

- (CBLQuery *)snapshottedObjectsQueryForSnapshot:(MPSnapshot *)snapshot
{
    CBLQuery *q = [[self.db.database viewNamed:@"snapshottedObjectsBySnapshotID"] createQuery];
    q.prefetch = YES;
    assert(q);
    
    return q;
}

- (NSArray *)snapshottedObjectsForSnapshot:(MPSnapshot *)snapshot
{
    NSError *err = nil;
    CBLQueryEnumerator *qenum = [[self snapshottedObjectsQueryForSnapshot:snapshot] run:&err];
    if (!qenum)
    {
        assert(err);
        [[self.packageController notificationCenter] postErrorNotification:err];
    }
    return [self managedObjectsForQueryEnumerator:qenum];
}

@end


#pragma mark -

@implementation MPSnapshottedAttachmentsController

- (instancetype)initWithSnapshotsController:(MPSnapshotsController *)controller error:(NSError **)err
{
    if (self = [super initWithPackageController:controller.packageController database:controller.db error:err])
    {
        _snapshotsController = controller;
    }
    
    return self;
}

- (void)configureViews
{
    [super configureViews];
    
    [self viewNamed:@"snapshottedAttachmentsBySnapshotID" setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit)
     {
         if ([doc[@"objectType"] isEqualToString:@"MPSnapshottedAttachment"])
             emit(doc[@"snapshotID"], nil);
     } version:@"1.0"];
    
    [self viewNamed:@"snapshottedAttachmentsBySHA" setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit)
     {
        if ([doc[@"objectType"] isEqualToString:@"MPSnapshottedAttachment"])
            emit(doc[@"sha"], nil);
    } version:@"1.0"];
}

- (CBLQuery *)snapshottedAttachmentsQueryForSnapshot:(MPSnapshot *)snapshot
{
    CBLQuery *q = [[self.db.database viewNamed:@"snapshottedAttachmentsBySnapshotID"] createQuery];
    q.prefetch = YES;
    return q;
}

- (NSArray *)snapshottedAttachmentsForSnapshot:(MPSnapshot *)snapshot
{
    NSError *err = nil;
    
    CBLQueryEnumerator *qenum = [[self snapshottedAttachmentsQueryForSnapshot:snapshot] run:&err];
    if (!qenum)
    {
        [[self.packageController notificationCenter] postErrorNotification:err];
        return nil;
    }
    
    return [self managedObjectsForQueryEnumerator:qenum];
}

- (CBLQuery *)snapshottedAttachmentsQueryForSHA:(NSString *)sha
{
    CBLQuery *q = [[self.db.database viewNamed:@"snapshottedAttachmentsBySHA"] createQuery];
    q.prefetch = YES;
    q.keys = @[sha];
    return q;
}

- (MPSnapshottedAttachment *)snapshottedAttachmentForSHA:(NSString *)sha
{
    NSError *err = nil;
    NSArray *attachmentsForSHA = [self managedObjectsForQueryEnumerator:[[self snapshottedAttachmentsQueryForSHA:sha] run:&err]];
    
    if (!attachmentsForSHA)
    {
        [[self.packageController notificationCenter] postErrorNotification:err];
        return nil;
    }
    
    // TODO: Handle syncing conflict?
    // More than one can be harmless, one of the objects needs deleting. Which one of multiples is deleted makes no difference
    assert(attachmentsForSHA.count <= 1);
    return [attachmentsForSHA firstObject];
}

@end