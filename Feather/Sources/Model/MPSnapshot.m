//
//  MPSnapshot.m
//  Feather
//
//  Created by Matias Piipari on 03/10/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPSnapshot.h"

#import "MPSnapshotsController+Protected.h"

#import "NSData+MPExtensions.h"

@interface MPSnapshot ()
{
    // hack to allow setting document identifier based on
    // snapshotted document ID + revision before calling -initWithNewDocumentForController:
    __weak NSString *__name;
}
@end

@implementation MPSnapshot

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"MPInvalidInitException" reason:nil userInfo:nil];
    return nil;
}

- (MPSnapshot *)initWithController:(MPSnapshotsController *)sc
                              name:(NSString *)name
{
    __name = name;
    if (self = [super initWithNewDocumentForController:sc])
    {
        self.name = name;
        self.timestamp = [NSDate date];
    }
    
    return self;
}

+ (NSString *)idForSnapshotWithName:(NSString *)name inDatabase:(CBLDatabase *)db
{
    assert(name);
    //return [NSString stringWithFormat:@"%@:%@", NSStringFromClass([self class]), name];
    return [NSString stringWithFormat:@"%@_%@", NSStringFromClass([self class]), name];
}

- (NSString *)idForNewDocumentInDatabase:(CBLDatabase *)db
{
    assert(__name);
    return [[self class] idForSnapshotWithName:__name inDatabase:db];
}

- (NSString *)name
{ return [self getValueOfProperty:@"name"]; }

- (void)setName:(NSString *)name
{ [self setValue:name ofProperty:@"name"]; }

- (void)setTimestamp:(NSDate *)timestamp
{ [self setValue:@([timestamp timeIntervalSince1970]) ofProperty:@"timestamp"]; }

- (NSDate *)timestamp
{ return [NSDate dateWithTimeIntervalSince1970:[[self getValueOfProperty:@"timestamp"] doubleValue]]; }

@end

@interface MPSnapshottedObject ()
{
    // hack to allow setting document identifier based on
    // snapshotted document ID + revision before calling -initWithNewDocumentForController:
    __weak NSString *__snapshottedDocumentID;
    __weak NSString *__snapshottedRevisionID;
}
@end

@implementation MPSnapshottedObject

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"MPInvalidInitException" reason:nil userInfo:nil];
    return nil;
}

- (MPSnapshottedObject *)initWithController:(MPSnapshottedObjectsController *)sc
                                   snapshot:(MPSnapshot *)snapshot
                          snapshottedObject:(MPManagedObject *)obj
{
    __snapshottedDocumentID = obj.document.documentID;
    __snapshottedRevisionID = obj.document.currentRevisionID;
    
    if (self = [super initWithNewDocumentForController:sc])
    {
        assert(snapshot);
        assert(snapshot.document.documentID);
        self.snapshotID = snapshot.document.documentID;
        
        self.snapshottedObjectClass = obj.class;
        self.snapshottedDocumentID = obj.document.documentID;
        self.snapshottedRevisionID = obj.document.currentRevisionID;
        self.snapshottedProperties = obj.document.properties;
    
        // TODO: Save attachments (their SHAs here and the object data in the snapshot database).
    }
    
    return self;
}

+ (NSString *)idForSnapshottedObjectWithDocumentID:(NSString *)documentID
                                        revisionID:(NSString *)revisionID
                                        inDatabase:(CBLDatabase *)db
{
    assert(documentID);
    assert(revisionID);
    return [NSString stringWithFormat:@"%@:%@:%@",
            NSStringFromClass(self), documentID, revisionID];
}

- (NSString *)idForNewDocumentInDatabase:(CBLDatabase *)db
{
    assert(__snapshottedDocumentID);
    assert(__snapshottedRevisionID);
    return [[self class] idForSnapshottedObjectWithDocumentID:__snapshottedDocumentID
                                                   revisionID:__snapshottedRevisionID
                                                   inDatabase:db];
}

- (NSString *)snapshotID
{ return [self getValueOfProperty:@"snapshotID"]; }
- (void)setSnapshotID:(NSString *)snapshotID
{ [self setValue:snapshotID ofProperty:@"snapshotID"]; }

- (MPSnapshot *)snapshot
{
    NSString *snapshotID = self.snapshotID;
    assert(snapshotID);
    
    MPSnapshot *snapshot = [MPSnapshot modelForDocument:[self.database documentWithID:snapshotID]];
    assert(snapshot);
    
    return snapshot;
}

- (NSString *)snapshottedDocumentID
{ return [self getValueOfProperty:@"snapshottedDocumentID"]; }

- (void)setSnapshottedDocumentID:(NSString *)snapshottedDocumentID
{ [self setValue:snapshottedDocumentID ofProperty:@"snapshottedDocumentID"]; }

- (NSString *)snapshottedRevisionID
{ return [self getValueOfProperty:@"snapshottedRevisionID"]; }

- (void)setSnapshottedRevisionID:(NSString *)snapshottedRevisionID
{ [self setValue:snapshottedRevisionID ofProperty:@"snapshottedRevisionID"]; }

- (void)setSnapshottedProperties:(NSDictionary *)props
{ [self setValue:props ofProperty:@"snapshottedProperties"]; }

- (NSString *)snapshottedProperties
{ return [self getValueOfProperty:@"snapshottedProperties"]; }

- (Class)snapshottedObjectClass {
    Class cls = [self getValueOfProperty:@"snapshottedObjectClass"];
    assert(cls);
    return cls;
}

- (void)setSnapshottedObjectClass:(Class)snapshottedObjectClass
{
    assert(snapshottedObjectClass);
    [self setValue:NSStringFromClass(snapshottedObjectClass) ofProperty:@"snapshottedObjectClass"];
}

@end


#pragma mark - 

@interface MPSnapshottedAttachment ()
@property (readwrite, copy) NSString *sha;
@property (readwrite, copy) NSString *contentType;
@property (readwrite, strong) CBLAttachment *attachment;
@end

@implementation MPSnapshottedAttachment

- (instancetype)init
{
    @throw [NSException exceptionWithName:@"MPInvalidInitException" reason:nil userInfo:nil];
}

- (instancetype)initWithSnapshotsController:(MPSnapshotsController *)controller
                                 attachment:(CBLAttachment *)attachment
                                      error:(NSError **)err
{
    assert(controller);
    assert(attachment);
    
    NSData *attachmentBody = attachment.content;
    assert(attachmentBody);
    
    NSString *shaDigest = [attachmentBody sha1DigestString];

    MPSnapshottedAttachment *a = [controller.snapshottedAttachmentsController snapshottedAttachmentForSHA:shaDigest];
    
    if (a)
    {
        assert([a.contentType isEqualToString:attachment.contentType]);
        return a;
    }
    
    if (self = [super initWithNewDocumentForController:controller.snapshottedAttachmentsController])
    {
        
        NSString *contentType = attachment.contentType;
        assert(contentType);
        
        if (![self save:err])
            return nil;
        
        self.sha = shaDigest;
        self.contentType = [attachment contentType];
        
        [self setAttachmentNamed:@"attachment" withContentType:contentType content:attachmentBody];
    }
    
    return self;
}

- (void)setSha:(NSString *)sha
{ [self setValue:sha ofProperty:@"sha"]; }

- (NSString *)sha
{ return [self getValueOfProperty:@"sha"]; }

- (void)setContentType:(NSString *)contentType
{ [self setValue:contentType ofProperty:@"contentType"]; }

- (NSString *)contentType
{ return [self getValueOfProperty:@"contentType"]; }

@end