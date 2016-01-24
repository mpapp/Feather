//
//  NSNotificationCenter+Feather.m
//  Feather
//
//  Created by Matias Piipari on 29/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "NSNotificationCenter+MPManagedObjectExtensions.h"
#import "MPManagedObject.h"
#import "MPDatabasePackageController.h"

@import RegexKitLite;
@import ObjectiveC;
@import FeatherExtensions;

static NSString * const MPManagedObjectClassPrefix = @"MP";

NSString * const MPNotificationNameManagedObjectShared = @"MPNotificationNameManagedObjectShared";

NSString * const MPNotificationNameSingleMasterSelection   = @"MPNotificationNameSingleMasterSelection";
NSString * const MPNotificationNameMultipleMasterSelection = @"MPNotificationNameMultipleMasterSelection";
NSString * const MPNotificationNameSingleDetailSelection   = @"MPNotificationNameSingleDetailSelection";
NSString * const MPNotificationNameMultipleDetailSelection = @"MPNotificationNameMultipleDetailSelection";

@protocol MPManagedObjectChangeObserver;

@implementation NSNotificationCenter (MPManagedObjectExtensions)

+ (void)initialize
{
    [super initialize];
    [self managedObjectNotificationNameDictionary];
}

+ (NSArray *)managedObjectChangeTypes
{
    return @[ @(MPChangeTypeAdd), @(MPChangeTypeRemove), @(MPChangeTypeUpdate) ];
}

+ (NSDictionary *)managedObjectChangeTypeStrings
{
    return @{
                @(MPChangeTypeAdd):@"Add",
                @(MPChangeTypeUpdate):@"Update",
                @(MPChangeTypeRemove):@"Remove"
            };
}

+ (NSDictionary *)managedObjectNotificationNameDictionary
{
    static NSDictionary *changeTypeDict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,
    ^{
        assert([NSNotificationCenter managedObjectChangeTypeStrings].count == [NSNotificationCenter managedObjectChangeTypes].count);
        
        NSArray *subclasses = MPManagedObject.subclasses;
        NSUInteger subclassCount = subclasses.count;

        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:subclassCount * [NSNotificationCenter managedObjectChangeTypes].count];
        
        for (NSNumber *changeType in [NSNotificationCenter managedObjectChangeTypes])
        {
            NSMutableDictionary *changeTypesForClass = [NSMutableDictionary dictionaryWithCapacity:subclassCount];
            d[changeType] = changeTypesForClass;
            NSString *changeTypeStr = [NSNotificationCenter managedObjectChangeTypeStrings][changeType];
            assert(changeTypeStr);
            
            for (Class subclass in subclasses)
            {
                if ([NSStringFromClass(subclass) hasSuffix:@"Mixin"]) continue;
                
                Class closestControllerClass = [MPDatabasePackageController controllerClassForManagedObjectClass:subclass];
                Class closestModelClass = [closestControllerClass managedObjectClass];
                NSParameterAssert(closestControllerClass);
                NSParameterAssert(closestModelClass);
                NSParameterAssert(closestModelClass != [MPManagedObject class]);
                NSParameterAssert([subclass isSubclassOfClass:closestModelClass]);
                
                NSString *closestModelClassName = NSStringFromClass(closestModelClass);
                
                NSString *unprefixedSubclassName =
                    [closestModelClassName stringByReplacingOccurrencesOfRegex:
                        [NSString stringWithFormat:@"^%@", MPManagedObjectClassPrefix] withString:@""];
                
                changeTypesForClass[NSStringFromClass(subclass)] =
                @{
                    @"has" : [NSString stringWithFormat:@"has%@%@", [changeTypeStr stringByTranslatingPresentToPastTense], unprefixedSubclassName],
                    @"did"  : [NSString stringWithFormat:@"did%@%@" , changeTypeStr, unprefixedSubclassName] };
            }
            
            d[changeType] = [changeTypesForClass copy];
        }
        
        changeTypeDict = [d copy];
    });
    
    return changeTypeDict;
}

+ (NSString *)notificationNameForRecentChangeOfType:(MPChangeType)changeType
                              forManagedObjectClass:(Class)moClass
{
    assert([moClass isSubclassOfClass:[MPManagedObject class]]);
    assert(moClass != [MPManagedObject class]);
    NSString *notificationName =
    [NSNotificationCenter managedObjectNotificationNameDictionary][@(changeType)][NSStringFromClass(moClass)][@"has"];
    assert(notificationName);
    return notificationName;
}

+ (NSString *)notificationNameForPastChangeOfType:(MPChangeType)changeType
                            forManagedObjectClass:(Class)moClass
{
    assert([moClass isSubclassOfClass:[MPManagedObject class]]);
    assert(moClass != [MPManagedObject class]);
    NSString *notificationName =
        [NSNotificationCenter managedObjectNotificationNameDictionary][@(changeType)][NSStringFromClass(moClass)][@"did"];
    assert(notificationName);
    return notificationName;
}

- (void)addPastChangeObserver:(id<MPManagedObjectChangeObserver>)observer
     forManagedObjectsOfClass:(Class)moClass
{
    [self addPastChangeObserver:observer forManagedObjectsOfClass:moClass
                         didAdd:nil didUpdate:nil didRemove:nil];
}

- (void)addRecentChangeObserver:(id<MPManagedObjectRecentChangeObserver>)observer
       forManagedObjectsOfClass:(Class)moClass
{
    [self addRecentChangeObserver:observer
         forManagedObjectsOfClass:moClass hasAdded:nil hasUpdated:nil hasRemoved:nil];
}

- (void)addRecentChangeObserver:(id<MPManagedObjectRecentChangeObserver>)observer
       forManagedObjectsOfClass:(Class)moClass
                       hasAdded:(MPRecentChangeObserverCallback)willAddBlock
                     hasUpdated:(MPRecentChangeObserverCallback)willUpdateBlock
                     hasRemoved:(MPRecentChangeObserverCallback)willRemoveBlock
{
    assert([moClass isSubclassOfClass:[MPManagedObject class]]);
    assert(moClass != [MPManagedObject class]);
    
    NSString *classStr = NSStringFromClass(moClass);
    
    for (NSNumber *changeType in [NSNotificationCenter managedObjectChangeTypes])
    {
        NSString *recentPastNotificationName = [NSNotificationCenter managedObjectNotificationNameDictionary][changeType][classStr][@"has"];
        assert(recentPastNotificationName != nil);
        
        SEL recentPastObserverSelector = NSSelectorFromString([recentPastNotificationName stringByAppendingString:@":"]);
        [self addObserver:observer
                 selector:recentPastObserverSelector
                     name:recentPastNotificationName object:nil];
        
        if (![observer respondsToSelector:recentPastObserverSelector] &&
            [changeType isEqualToNumber:@(MPChangeTypeAdd)])
        {
            class_addMethod([observer class], recentPastObserverSelector,
                            imp_implementationWithBlock(willAddBlock), "v@:@");
        }
        else if (![observer respondsToSelector:recentPastObserverSelector] &&
                 [changeType isEqualToNumber:@(MPChangeTypeUpdate)])
        {
            class_addMethod([observer class], recentPastObserverSelector,
                            imp_implementationWithBlock(willUpdateBlock), "v@:@");
        }
        else if (![observer respondsToSelector:recentPastObserverSelector] &&
                 [changeType isEqualToNumber:@(MPChangeTypeRemove)]) {
            class_addMethod([observer class], recentPastObserverSelector,
                            imp_implementationWithBlock(willRemoveBlock), "v@:@");
        }
    }
}

- (void)addPastChangeObserver:(id<MPManagedObjectChangeObserver>)observer
     forManagedObjectsOfClass:(Class)moClass
                       didAdd:(MPChangeObserverCallback)didAddBlock
                    didUpdate:(MPChangeObserverCallback)didUpdateBlock
                    didRemove:(MPChangeObserverCallback)didRemoveBlock
{
    assert([moClass isSubclassOfClass:[MPManagedObject class]]);
    assert(moClass != [MPManagedObject class]);
    
    NSString *classStr = NSStringFromClass(moClass);
    
    for (NSNumber *changeType in [NSNotificationCenter managedObjectChangeTypes])
    {
        NSString *pastNotificationName = [NSNotificationCenter managedObjectNotificationNameDictionary][changeType][classStr][@"did"];
        assert(pastNotificationName != nil);
        
        SEL pastObserverSelector = NSSelectorFromString([pastNotificationName stringByAppendingString:@":"]);
        [self addObserver:observer
                 selector:pastObserverSelector
                     name:pastNotificationName object:nil];
        
        if (![observer respondsToSelector:pastObserverSelector] &&
            [changeType isEqualToNumber:@(MPChangeTypeAdd)] && didAddBlock)
        {
            class_addMethod([observer class], pastObserverSelector,
                            imp_implementationWithBlock(didAddBlock), "v@:@");
        }
        
        if (![observer respondsToSelector:pastObserverSelector] &&
                 [changeType isEqualToNumber:@(MPChangeTypeUpdate)] && didUpdateBlock)
        {
            class_addMethod([observer class], pastObserverSelector,
                            imp_implementationWithBlock(didUpdateBlock), "v@:@");
        }
        
        if (![observer respondsToSelector:pastObserverSelector] &&
                 [changeType isEqualToNumber:@(MPChangeTypeRemove)] && didRemoveBlock) {
            class_addMethod([observer class], pastObserverSelector,
                            imp_implementationWithBlock(didRemoveBlock), "v@:@");
        }
    }
}

- (void)addObjectSelectionChangeObserver:(id<MPObjectSelectionObserver>)observer
{
    [self addObserver:observer selector:@selector(didChangeDetailSelectionToSingleObject:)
                 name:MPNotificationNameSingleDetailSelection object:nil];
    
    [self addObserver:observer selector:@selector(didChangeDetailSelectionToMultipleObjects:)
                 name:MPNotificationNameMultipleDetailSelection object:nil];
    
    [self addObserver:observer selector:@selector(didChangeMasterSelectionToSingleObject:)
                 name:MPNotificationNameSingleMasterSelection object:nil];
    
    [self addObserver:observer selector:@selector(didChangeMasterSelectionToMultipleObjects:)
                 name:MPNotificationNameMultipleMasterSelection object:nil];
}

- (void)postNotificationForChangingMasterSelectionToSingleObject:(id)obj userInfo:(NSDictionary *)userInfo
{
    [self postNotificationName:MPNotificationNameSingleMasterSelection object:obj userInfo:userInfo];
}

- (void)postNotificationForChangingDetailSelectionToSingleObject:(id)obj userInfo:(NSDictionary *)userInfo
{
    [self postNotificationName:MPNotificationNameSingleDetailSelection object:obj userInfo:userInfo];
}

- (void)postNotificationForChangingMasterSelectionToMultipleObjects:(NSArray *)objs userInfo:(NSDictionary *)userInfo
{
    [self postNotificationName:MPNotificationNameMultipleMasterSelection object:objs userInfo:userInfo];
}

- (void)postNotificationForChangingDetailSelectionToMultipleObjects:(NSArray *)objs userInfo:(NSDictionary *)userInfo
{
    [self postNotificationName:MPNotificationNameMultipleDetailSelection object:objs userInfo:userInfo];
}


@end

@implementation NSNotification (MPManagedObjectExtensions)

- (MPManagedObject *)managedObject
{
    assert([self.object isKindOfClass:[MPManagedObject class]]);
    return self.object;
}

@end

// MARK: - MPDatabaseExtensions

@implementation NSNotificationCenter (MPDatabaseExtensions)


- (void)addObserver:(id<MPDatabaseReplicationObserver>)observer forReplicationOfDatabase:(MPDatabase *)db
{
    [self addObserver:observer
             selector:@selector(didCompletePersistentPullReplication:)
                 name:[NSNotificationCenter notificationNameForReplicationEventType:MPReplicationEventTypePersistentPullComplete] object:db];
    
    [self addObserver:observer
             selector:@selector(didCompletePersistentPullReplication:)
                 name:[NSNotificationCenter notificationNameForReplicationEventType:MPReplicationEventTypePersistentPushComplete] object:db];
}

+ (NSString *)notificationNameForReplicationEventType:(MPReplicationEventType)eventType
{
    if (eventType == MPReplicationEventTypePersistentPullComplete)
    { return @"MPReplicationPersistentPullComplete"; }
    else if (eventType == MPReplicationEventTypePersistentPushComplete)
    { return @"MPReplicationPersistentPushComplete"; }
    
    assert(false);
    return nil;
}

- (void)addManagedObjectSharingObserver:(id<MPManagedObjectSharingObserver>)observer
{
    [self addObserver:observer selector:@selector(didShareManagedObject:)
                 name:MPNotificationNameManagedObjectShared object:nil];
}

- (void)postNotificationForSharingManagedObject:(MPManagedObject *)obj
{
    [self postNotificationName:MPNotificationNameManagedObjectShared object:obj];
}

@end