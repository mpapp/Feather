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
#import <MPFoundation/MPContributor+Manuscripts.h>

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

@end

@implementation MPContributorsController

- (MPContributor *)me {
    if (!_me)
    {
        _me = [self newObject];
    }
    
    return _me;
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
         
         // if role has not been set, assume the author has role 'author'
         if (!doc[@"role"] || [doc[@"role"] isEqualToString:MPContributorRoleAuthor])
         {
             emit(MPContributorRoleAuthor, nil);
             return;
         }
         
         emit(doc[@"role"], nil);
     } version:@"1.1"];
}

- (NSArray *)contributorsInRole:(NSString *)role {
    return [[self objectsMatchingQueriedView:@"contributorsByRole"
                                        keys:@[role]]
            sortedArrayUsingComparator:^NSComparisonResult(MPContributor *a, MPContributor *b)
    {
        NSComparisonResult r = [@(a.priority) compare:@(b.priority)];
        if (r != NSOrderedSame)
            return r;
        
        return [a.nameString compare:b.nameString];
    }];
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
    _cachedContributors
        = [[self allObjects] sortedArrayUsingComparator:
           ^NSComparisonResult(MPContributor *a, MPContributor *b) {
        if (a.priority > b.priority)
            return NSOrderedDescending;
        else if (a.priority < b.priority)
            return NSOrderedAscending;
        
        return [a compare:b];
    }];
    assert(_cachedContributors);
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
        NSParameterAssert(oldIndex != index);
        
        [newUniverse removeObject:contributor];
        [newUniverse insertObject:contributor atIndex:index];
        
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

@end