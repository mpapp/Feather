//
//  NSNotificationCenter+Manuscripts.m
//  Manuscripts
//
//  Created by Matias Piipari on 29/09/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
//

#import "NSNotificationCenter+Manuscripts.h"
#import "MPManagedObject.h"

#import "RegexKitLite.h"
#import "NSString+Manuscripts.h"
#import "NSObject+Manuscripts.h"

#import <objc/runtime.h>

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
    [self notificationNameDictionary];
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

+ (NSDictionary *)notificationNameDictionary
{
    static NSDictionary *changeTypeDict = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,
    ^{
        assert([NSNotificationCenter managedObjectChangeTypeStrings].count == [NSNotificationCenter managedObjectChangeTypes].count);
        
        NSArray *subclasses = [NSObject subclassesForClass:[MPManagedObject class]];
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
                NSString *subclassName = NSStringFromClass(subclass);
                NSString *unprefixedSubclassName =
                    [subclassName  stringByReplacingOccurrencesOfRegex:
                        [NSString stringWithFormat:@"^%@", MPManagedObjectClassPrefix] withString:@""];
                
                changeTypesForClass[subclassName] =
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

+ (NSString *)notificationNameForRecentChangeOfType:(MPChangeType)changeType forManagedObjectClass:(Class)moClass
{
    assert([moClass isSubclassOfClass:[MPManagedObject class]]);
    assert(moClass != [MPManagedObject class]);
    NSString *notificationName =
    [NSNotificationCenter notificationNameDictionary][@(changeType)][NSStringFromClass(moClass)][@"has"];
    assert(notificationName);
    return notificationName;
}

+ (NSString *)notificationNameForPastChangeOfType:(MPChangeType)changeType forManagedObjectClass:(Class)moClass
{
    assert([moClass isSubclassOfClass:[MPManagedObject class]]);
    assert(moClass != [MPManagedObject class]);
    NSString *notificationName =
        [NSNotificationCenter notificationNameDictionary][@(changeType)][NSStringFromClass(moClass)][@"did"];
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
         forManagedObjectsOfClass:moClass
                          hasAdded:nil hasUpdated:nil hasRemoved:nil];
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
        NSString *recentPastNotificationName = [NSNotificationCenter notificationNameDictionary][changeType][classStr][@"has"];
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
        NSString *pastNotificationName = [NSNotificationCenter notificationNameDictionary][changeType][classStr][@"did"];
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

- (void)postNotificationForChangingMasterSelectionToSingleObject:(id)obj
{
    [self postNotificationName:MPNotificationNameSingleMasterSelection object:obj userInfo:nil];
}

- (void)postNotificationForChangingDetailSelectionToSingleObject:(id)obj
{
    [self postNotificationName:MPNotificationNameSingleDetailSelection object:obj userInfo:nil];
}

- (void)postNotificationForChangingMasterSelectionToMultipleObjects:(NSArray *)objs
{
    [self postNotificationName:MPNotificationNameMultipleMasterSelection object:objs userInfo:nil];
}

- (void)postNotificationForChangingDetailSelectionToMultipleObjects:(NSArray *)objs
{
    [self postNotificationName:MPNotificationNameMultipleDetailSelection object:objs userInfo:nil];
}


@end

@implementation NSNotification (MPManagedObjectExtensions)

- (MPManagedObject *)managedObject
{
    assert([self.object isKindOfClass:[MPManagedObject class]]);
    return self.object;
}

@end

#pragma mark - MPDatabaseExtensions

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