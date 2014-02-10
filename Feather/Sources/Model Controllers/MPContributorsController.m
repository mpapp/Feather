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

#import "NSArray+MPExtensions.h"
#import "NSBundle+MPExtensions.h"

#import <CouchCocoa/CouchCocoa.h>
#import <CouchCocoa/CouchDesignDocument_Embedded.h>


NSString * const MPContributorRoleAuthor = @"author";
NSString * const MPContributorRoleEditor = @"editor";
NSString * const MPContributorRoleTranslator = @"translator";

@interface MPContributorsController ()
{
    MPContributor *_me;
}

@property (readwrite, strong) NSArray *cachedContributors;

@end

@implementation MPContributorsController

- (MPContributor *)me
{
    if (!_me)
    {
        _me = [self newObject];
    }
    
    return _me;
}

- (void)configureDesignDocument:(CouchDesignDocument *)designDoc
{
    [super configureDesignDocument:designDoc];
    
    NSString *allObjsViewName = [self allObjectsViewName];
    [designDoc defineViewNamed:allObjsViewName mapBlock:self.allObjectsBlock
                       version:[[NSBundle appBundle] bundleVersionString]];
    
    [designDoc defineViewNamed:@"contributorsByRole"
                      mapBlock:^(NSDictionary *doc, TDMapEmitBlock emit)
    {
        // if role has not been set, assume the author has role 'author' 
        if (!doc[@"role"] || [doc[@"role"] isEqualToString:MPContributorRoleAuthor])
        {
            emit(MPContributorRoleAuthor, nil);
            return;
        }

        emit(doc[@"role"], nil);
    } version:@"1.0"];
}

- (NSArray *)contributorsInRole:(NSString *)role
{
    CouchQuery *query = [self.designDocument queryViewNamed:@"contributorsByRole"];
    query.prefetch = YES;
    query.key = role;
    return [self managedObjectsForQueryEnumerator:[query rows]];
}

- (NSArray *)allContributors
{
    if (!_cachedContributors)
    {
        [self refreshCachedContributors];
    }
    
    return _cachedContributors;
}

- (NSArray *)allAuthors
{
    return [self contributorsInRole:MPContributorRoleAuthor];
}

- (NSArray *)allEditors
{
    return [self contributorsInRole:MPContributorRoleEditor];
}

- (NSArray *)allTranslators
{
    return [self contributorsInRole:MPContributorRoleTranslator];
}

- (void)refreshCachedContributors
{
    _cachedContributors = [[self allObjects] sortedArrayUsingComparator:^NSComparisonResult(MPContributor *a, MPContributor *b) {
        if (a.priority > b.priority) return NSOrderedDescending;
        else if (a.priority < b.priority) return NSOrderedAscending;
        
        return [a compare:b];
    }];
    assert(_cachedContributors);
}

- (void)refreshCachedValues
{
    [super refreshCachedValues];
    [self refreshCachedContributors];
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

@end