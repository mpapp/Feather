//
//  MPContributor.m
//  Feather
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPContributor.h"
#import "MPContributorsController.h"
#import "MPDatabasePackageController.h"
#import "MPShoeboxPackageController.h"

#import "NSImage+MPExtensions.h"

#import <CouchbaseLite/CouchbaseLite.h>

@interface MPContributor ()
@property (readwrite) NSInteger priority;
@end

@interface MPContributorsController ()
@property (readwrite) MPContributor *me;
@end

@implementation MPContributor
@dynamic priority;
@dynamic category, role, contribution;
@dynamic isCorresponding;
@dynamic addressBookIDs;
@dynamic appInvitationDate;

// FIXME: Make abstract method in an abstract base class.
#ifndef MPAPP
@dynamic fullName;
#endif

- (NSArray *)identities {
    return [[self.controller.packageController contributorIdentitiesController] contributorIdentitiesForContributor:self];
}

- (BOOL)isMe {
    NSString *identifier = MPShoeboxPackageController.sharedShoeboxController.identifier;
    return [[self.identities valueForKey:@"identifier"] containsObject:identifier];
}

- (void)setIsMe:(BOOL)isMe {
    NSString *identifier = MPShoeboxPackageController.sharedShoeboxController.identifier;
    NSParameterAssert(identifier);
    
    MPContributorIdentity *identity = [self.identities filteredArrayUsingPredicate:
                                       [NSPredicate predicateWithBlock:^BOOL(MPContributorIdentity *identity, NSDictionary *bindings) {
        return [identity.identifier isEqualToString:identifier];
    }]].firstObject;
    

    if (isMe) {
        // self already has the required identity, nothing to do.
        if (identity)
            return;
        
        // unclaim existing contributor identities which already claim this identifier (self is me now).
        NSArray *existingContributorsWithID = [[self.controller.packageController contributorIdentitiesController] contributorsWithContributorIdentifier:identifier];
        for (MPContributor *c in existingContributorsWithID) {
            c.isMe = NO;
        }
        
        MPContributorIdentity *myIdentity = [[MPContributorIdentity alloc] initWithNewDocumentForController:[self.controller.packageController contributorIdentitiesController]];
        myIdentity.contributor = self;
        myIdentity.identifier = identifier;
        myIdentity.namespace = @"com.manuscriptsapp.shared.package.identity";
        
        ((MPContributorsController *)self.controller).me = self;
    }
    else {
        // delete found identity linking self to the shared package identifier.
        [identity deleteDocument];
    }
}

- (NSImage *)thumbnailImage {
    if ([self valueForKey:@"avatarImage"]) {
        return [self valueForKey:@"avatarImage"];
    }
    
    NSImage *img = [NSImage imageNamed:@"face-monkey.png"];
    [img setTemplate:YES];
    return img;
}

+ (NSSet *)keyPathsForValuesAffectingThumbnailImage {
    return [NSSet setWithArray:@[@"avatarImage"]];
}

- (NSArray *)siblings {
    assert(self.controller);
    return [(MPContributorsController *)self.controller allContributors];
}

- (NSArray *)children {
    return @[];
}

- (NSUInteger)childCount {
    return 0;
}

- (BOOL)hasChildren {
    return NO;
}

- (id)parent {
    return nil;
}

- (NSString *)placeholderString {
    return @"First Last";
}

// FIXME: Make abstract methods in an abstract base class.
#ifndef MPAPP

- (NSComparisonResult)compare:(MPContributor *)contributor
{
    return [self.fullName caseInsensitiveCompare:contributor.fullName];
}

- (void)setTitle:(NSString *)title {
    [self setFullName:title];
}

- (NSString *)title {
    return [self fullName] ? [self fullName] : @"";
}

#endif

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@ (%@ rev:%@)]",
            self.fullName, self.documentID, self.document.currentRevisionID];
}

@end


#pragma mark -

@interface MPContributorIdentity ()
@property (readwrite) MPContributor *cachedContributor;
@end

@implementation MPContributorIdentity
@dynamic contributor, identifier, namespace;
@synthesize cachedContributor;

- (void)setContributor:(MPContributor *)contributor {
    NSAssert(!self.cachedContributor, @"Contributor should be set only once.");
    
    NSString *existingContributorID = [self getValueOfProperty:@"contributor"];
    if (existingContributorID && contributor.documentID)
        NSAssert([existingContributorID isEqualToString:contributor.documentID], @"");
    
    [self setValue:contributor.documentID ofProperty:@"contributor"];
    self.cachedContributor = contributor;
}

- (MPContributor *)contributor {
    if (self.cachedContributor)
        return self.cachedContributor;
    
    return [self.controller.packageController objectWithIdentifier:[self getValueOfProperty:@"contributor"]];
}

- (void)setIdentifier:(NSString *)identifier {
    NSAssert(![self getValueOfProperty:@"identifier"], @"Identifier should be set only once.");
    [self setValue:identifier ofProperty:@"identifier"];
}

- (void)setNamespace:(NSString *)namespace {
    NSAssert(![self getValueOfProperty:@"namespace"], @"Namespace should be set only once.");
    [self setValue:namespace ofProperty:@"namespace"];
}

- (BOOL)save:(NSError *__autoreleasing *)outError {
    NSAssert(self.contributor, @"Contributor should be set.");
    NSAssert(self.identifier, @"Identifier should be set.");
    NSAssert(self.namespace, @"namespace should be set.");
    
    return [super save:outError];
}

@end