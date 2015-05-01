//
//  MPContributorsController.m
//  Feather
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPContributor.h"
#import "MPContributorsController.h"
#import "MPManagedObjectsController+Protected.h"

#import "MPDatabase.h"

#import "NSString+MPExtensions.h"
#import "NSArray+MPExtensions.h"
#import "NSBundle+MPExtensions.h"
#import "NSNotificationCenter+ErrorNotification.h"

#import <CouchbaseLite/CouchbaseLite.h>

@interface MPContributor ()
@property (readwrite) NSInteger priority;
@end

NSString * const MPContributorRoleAuthor = @"author";
NSString * const MPContributorRoleEditor = @"editor";
NSString * const MPContributorRoleTranslator = @"translator";

@interface MPContributorsController ()
{
    MPContributor *_me;
}

@property (readwrite, strong) NSArray *cachedContributors;
@property (readwrite) MPContributor *me;

@end

@implementation MPContributorsController

- (MPContributor *)me {
    if (!_me)
    {
        
        
        _me = [self newObject];
        _me.fullName = NSFullUserName();
        _me.role = MPContributorRoleAuthor;
    }
    
    return _me;
}

- (void)setMe:(MPContributor *)contributor {
    _me = contributor;
}

- (MPContributor *)existingMe {
    MPContributor *me = nil;
    for (MPContributor *c in self.allObjects) {
        if (c.isMe) {
            NSAssert(!me, @"At least two 'me' contributors exist: %@ != %@", me, c);
            me = c;
        }
    }
    
    return me;
}

- (void)configureViews {
    [super configureViews];
    
    NSString *allObjsViewName = [self allObjectsViewName];
    
    CBLView *view = [self.db.database viewNamed:allObjsViewName];
    [view setMapBlock:self.allObjectsBlock version:@"1.1"];
    
    [[self.db.database viewNamed:@"contributorsByRole"] setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit)
     {
         if (![self managesDocumentWithDictionary:doc])
             return;
         
         // TODO: remove the following clause that ensures that if role has not been set, assume the author has role 'author'
         if (!doc[@"role"] || [doc[@"role"] isEqualToString:MPContributorRoleAuthor])
         {
             emit(MPContributorRoleAuthor, nil);
             return;
         }
         
         emit(doc[@"role"], nil);
     } version:@"1.1"];
    
    [[self.db.database viewNamed:@"contributorsByAddressBookID"] setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit) {
        if (![self managesDocumentWithDictionary:doc])
            return;
        
        if (!doc[@"addressBookIDs"])
            return;
        
        for (NSString *uniqueID in doc[@"addressBookIDs"])
            emit(uniqueID, nil);
    } version:@"1.0"];
    
    [[self.db.database viewNamed:@"contributorsByFullName"] setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit) {
        if (![self managesDocumentWithDictionary:doc])
            return;
        
        if (!doc[@"fullName"])
            return;
        
        emit(doc[@"fullName"], nil);
    } version:@"1.0"];
}

- (MPContributor *)contributorWithAddressBookID:(NSString *)personUniqueID {
    NSParameterAssert(personUniqueID);
    
    NSArray *contributors = [self objectsMatchingQueriedView:@"contributorsByAddressBookID" keys:@[personUniqueID]];
    NSAssert(contributors.count < 2, @"A maximum of one contributor should have been retrieved: %@", contributors);
    
    return contributors.firstObject;
}

- (NSArray *)contributorsWithFullName:(NSString *)fullName {
    NSParameterAssert(fullName);
    
    NSArray *contributors = [self objectsMatchingQueriedView:@"contributorsByFullName" keys:@[fullName]];
    NSAssert(contributors.count < 2, @"A maximum of one contributor should have been retrieved: %@", contributors);
    
    return contributors.firstObject;
}

- (NSArray *)contributorsInRole:(NSString *)role {
    NSAssert(self.contributorComparator, @"Assign contributorComparator to a non-nil value before calling -contributorsInRole.");
    return [[self objectsMatchingQueriedView:@"contributorsByRole"
                                        keys:@[role]]
            sortedArrayUsingComparator:self.contributorComparator];
}

- (NSArray *)allContributors {
    if (!_cachedContributors)
    {
        [self refreshCachedContributors];
        assert(_cachedContributors);
    }
    
    return _cachedContributors;
}

- (NSArray *)allAuthors {
    return [self contributorsInRole:MPContributorRoleAuthor];
}

- (NSArray *)allEditors {
    return [self contributorsInRole:MPContributorRoleEditor];
}

- (NSArray *)allTranslators {
    return [self contributorsInRole:MPContributorRoleTranslator];
}

- (void)refreshCachedContributors
{
    NSAssert(self.contributorComparator, @"contributorComparator needs to be assigned before calling -refreshCachedContributors.");
    _cachedContributors = [[self allObjects] sortedArrayUsingComparator:self.contributorComparator];
    NSParameterAssert(_cachedContributors);
}

- (void)refreshCachedValues {
    [super refreshCachedValues];
    [self refreshCachedContributors];
}

+ (NSUInteger)refreshPrioritiesForContributors:(NSArray *)contributors
                           changedContributors:(NSArray **)changedContributors {
    NSMutableArray *changed = [NSMutableArray new];
    
    [contributors enumerateObjectsUsingBlock:^(MPContributor *c,
                                               NSUInteger idx,
                                               BOOL *stop) {
        if (c.priority == idx)
            return;
        
        c.priority = idx;
        [changed addObject:c];
    }];
    
    if (changedContributors)
        *changedContributors = changed.copy;
    
    return changed.count;
}

+ (void)moveContributors:(NSArray *)contributors
     amongstContributors:(NSArray *)universeOfContributors
                 toIndex:(NSUInteger)index
      indexChangeHandler:(MPContributorPriorityChangeHandler)handler
{
    NSMutableArray *newUniverse = universeOfContributors.mutableCopy;
    
    for (NSInteger i = contributors.count - 1; i >= 0; i--) {
        MPContributor *contributor = contributors[i];
        NSUInteger oldIndex = [newUniverse indexOfObject:contributor];
        NSParameterAssert(oldIndex != NSNotFound);
        
        if (oldIndex == index)
            continue;
        
        [newUniverse removeObject:contributor];
        [newUniverse insertObject:contributor atIndex:index];
        
        if (handler)
            handler(contributor, oldIndex, index);
    }
    
    [self refreshPrioritiesForContributors:newUniverse changedContributors:nil];
}

#pragma mark -
#pragma mark Change notifications

- (void)hasAddedContributor:(NSNotification *)notification
{
    [self refreshCachedContributors];
}

- (void)hasUpdatedContributor:(NSNotification *)notification { }

- (void)hasRemovedContributor:(NSNotification *)notification
{
    if (_cachedContributors)
        { assert([_cachedContributors containsObject:notification.object]); }
    
    _cachedContributors = [_cachedContributors arrayByRemovingObject:notification.object];
}

#pragma mark - Deletion handling

- (void)willDeleteObject:(MPContributor *)object
{
    NSParameterAssert([object isKindOfClass:MPContributor.class]);
    
    [super willDeleteObject:object];
    [object.identities enumerateObjectsUsingBlock:^(MPContributorIdentity *c, NSUInteger idx, BOOL *stop) {
        [c deleteDocument];
    }];
    
    if (object == _me)
        _me = nil;
}

@end


#pragma mark -


@implementation MPContributorIdentitiesController

- (void)configureViews {
    [super configureViews];
    
    [[self.db.database viewNamed:@"contributor-identities-by-identifier"] setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit) {
        if (![self managesDocumentWithDictionary:doc])
            return;
        
        emit(doc[@"identifier"], nil);
    } version:@"1.0"];
    
    [[self.db.database viewNamed:@"contributor-identities-by-contributor"] setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit) {
        if (![self managesDocumentWithDictionary:doc])
            return;
        
        NSAssert(doc[@"contributor"], @"Expecting 'contributor' field in a contributor identity document: %@", doc);
        emit(doc[@"contributor"], nil);
    } version:@"1.0"];
    
    [[self.db.database viewNamed:self.allObjectsViewName] setMapBlock:self.allObjectsBlock version:@"1.0"];
}

- (NSArray *)contributorIdentitiesForContributor:(MPContributor *)contributor {
    return [[self objectsMatchingQueriedView:@"contributor-identities-by-contributor" keys:@[contributor.documentID]]
     mapObjectsUsingBlock:^id(MPContributorIdentity *c, NSUInteger idx) {
         return c.contributor;
    }];
}

- (NSArray *)contributorIdentitiesWithIdentifier:(NSString *)identifier {
    return [self objectsMatchingQueriedView:@"contributor-identities-by-identifier" keys:@[identifier]];
}

- (NSArray *)contributorsWithContributorIdentifier:(NSString *)identifier {
    return [[self contributorIdentitiesWithIdentifier:identifier] mapObjectsUsingBlock:
            ^id(MPContributorIdentity *identity, NSUInteger idx)
            {
                return identity.contributor;
            }];
}

- (NSArray *)contributorsWithContributorIdentity:(MPContributorIdentity *)identity {
    return [self contributorsWithContributorIdentifier:identity.identifier];
}

@end