//
//  MPContributorsController.m
//  Feather
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPDatabasePackageController.h"
#import "MPContributor.h"
#import "MPContributorsController.h"
#import "MPManagedObjectsController+Protected.h"

#import "MPDatabase.h"

#import "NSArray+MPExtensions.h"
#import "NSBundle+MPExtensions.h"
#import "NSNotificationCenter+ErrorNotification.h"

#import <CouchbaseLite/CouchbaseLite.h>


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

- (void)configureViews
{
    [super configureViews];
    
    NSString *allObjsViewName = [self allObjectsViewName];
    
    CBLView *view = [self.db.database viewNamed:allObjsViewName];
    [view setMapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit)
     {
         if (![self managesDocumentWithDictionary:doc])
             return;
         
         // if role has not been set, assume the author has role 'author'
         if (!doc[@"role"] || [doc[@"role"] isEqualToString:MPContributorRoleAuthor])
         {
             emit(MPContributorRoleAuthor, nil);
             return;
         }
         
         emit(doc[@"role"], nil);
     } version:@"1.1"];
}

- (NSArray *)contributorsInRole:(NSString *)role
{
    CBLQuery *query = [[self.db.database viewNamed:@"contributorsByRole"] createQuery];
    query.prefetch = YES;
    query.keys = @[ role ];
    
    NSError *err = nil;
    CBLQueryEnumerator *qenum = [query run:&err];
    if (!qenum)
    {
        [[self.packageController notificationCenter] postErrorNotification:err];
        return nil;
    }
    return [self managedObjectsForQueryEnumerator:qenum];
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
    _cachedContributors
        = [[self allObjects] sortedArrayUsingComparator:
           ^NSComparisonResult(MPContributor *a, MPContributor *b) {
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