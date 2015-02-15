//
//  NSNotificationCenter+Feather.h
//  Feather
//
//  Created by Matias Piipari on 29/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const MPNotificationNameManagedObjectShared;

extern NSString * const MPNotificationNameSingleMasterSelection;
extern NSString * const MPNotificationNameMultipleMasterSelection;
extern NSString * const MPNotificationNameSingleDetailSelection;
extern NSString * const MPNotificationNameMultipleDetailSelection;

@class MPManagedObject, MPDatabase;
/** An empty super-protocol for managed object observer protocols. These protocols are provided simply to help in guaranteeing program correctness during compile time and to make it easier to follow notifications emitted by MPManagedObject changes. */
@protocol MPManagedObjectChangeObserver <NSObject> @end

/** Same as MPManagedObjectChangeObserver, but notifications posted before the ones received by id<MPManagedObjectChangeObserver> instances (hasAdded, hasUpdated, hasRemoved before didAdd, didUpdate, didRemove). User interface elements should generally implement MPManagedObjectRecentChangeObserver, and backend elements the MPManagedObjectChangeObserver.
 */
@protocol MPManagedObjectRecentChangeObserver <NSObject> @end

typedef void (^MPRecentChangeObserverCallback)(id<MPManagedObjectRecentChangeObserver> _self, NSNotification *notification);
typedef void (^MPChangeObserverCallback)(id<MPManagedObjectChangeObserver> _self, NSNotification *notification);

@protocol MPDatabaseReplicationObserver;
@protocol MPManagedObjectSharingObserver;
@protocol MPObjectSelectionObserver;

typedef enum MPChangeType {
    MPChangeTypeAdd = 0,
    MPChangeTypeUpdate = 1,
    MPChangeTypeRemove = 2
} MPChangeType;

typedef enum MPReplicationEventType {
    MPReplicationEventTypePersistentPullProgressUpdated = 0,
    MPReplicationEventTypePersistentPullComplete = 1,
    MPReplicationEventTypePersistentPushProgressUpdated = 2,
    MPReplicationEventTypePersistentPushComplete = 3
} MPReplicationEventType;

/** A MPManagedObject related utility category on NSNotificationCenter. */
@interface NSNotificationCenter (MPManagedObjectExtensions)

- (void)addRecentChangeObserver:(id<MPManagedObjectRecentChangeObserver>)observer
       forManagedObjectsOfClass:(Class)moClass;

- (void)addRecentChangeObserver:(id<MPManagedObjectRecentChangeObserver>)observer
       forManagedObjectsOfClass:(Class)moClass
                       hasAdded:(MPRecentChangeObserverCallback)didAddBlock
                     hasUpdated:(MPRecentChangeObserverCallback)didUpdateBlock
                     hasRemoved:(MPRecentChangeObserverCallback)didRemoveBlock;

/** Adds an observer for change notifications emitted by MPManagedObject instances.
  * @param observer The object which is to observe managed object notifications.
  * @param moClass The managed object class whose instances are to be observed by the sender. */
- (void)addPastChangeObserver:(id<MPManagedObjectChangeObserver>)observer
     forManagedObjectsOfClass:(Class)moClass;

/** Adds an observer for past change notififications emitted by MPManagedObject instances. This is the hardcore version of -addPastChangeObserver:forManagedObjectsOfClass: which allows you to define the method default implementations in case the observer class doesn't define them. The defaultDidAddImplementation:, defaultDidUpdateImplementation:, defaultDidRemoveImplementation arguments are unused if the corresponding method is defined. */
- (void)addPastChangeObserver:(id<MPManagedObjectChangeObserver>)observer
     forManagedObjectsOfClass:(Class)moClass
                       didAdd:(MPChangeObserverCallback)didAddBlock
                    didUpdate:(MPChangeObserverCallback)didUpdateBlock
                    didRemove:(MPChangeObserverCallback)didRemoveBlock;

+ (NSString *)notificationNameForRecentChangeOfType:(MPChangeType)changeType forManagedObjectClass:(Class)moClass;
+ (NSString *)notificationNameForPastChangeOfType:(MPChangeType)changeType forManagedObjectClass:(Class)moClass;

- (void)addObjectSelectionChangeObserver:(id<MPObjectSelectionObserver>)observer;

/** Notify of master selection changing to a single object. 
  * User info dictionary can contain hints of how view should react. */
- (void)postNotificationForChangingMasterSelectionToSingleObject:(id)obj userInfo:(NSDictionary *)userInfo;

/** Notify of detail selection changing to a multiple selection.
 * User info dictionary can contain hints of how view should react. */
- (void)postNotificationForChangingDetailSelectionToSingleObject:(id)obj userInfo:(NSDictionary *)userInfo;

/** Notify of master selection changing to a single object.
 * User info dictionary can contain hints of how view should react. */
- (void)postNotificationForChangingMasterSelectionToMultipleObjects:(NSArray *)objs userInfo:(NSDictionary *)userInfo;

/** Notify of detail selection changing to a multiple selection.
 * User info dictionary can contain hints of how view should react. */
- (void)postNotificationForChangingDetailSelectionToMultipleObjects:(NSArray *)objs userInfo:(NSDictionary *)userInfo;

/** Hierarchy of dictionaries of the managed object notification names by class name 
  * (1st level dictionary) and the change type (2nd level dictionary). 
  * Exposed publicly mostly for enabling testing, accessing otherwise not advisable. */
+ (NSDictionary *)managedObjectNotificationNameDictionary;

@end

@interface NSNotificationCenter (MPDatabaseExtensions)

/** Adds an observer for replication notifications emitted by MPDatabase instances.
 * @param observer The object which is to observe managed object notifications.
 * @param db The MPDatabase instance whose replication the observer is to observe. */
- (void)addObserver:(id<MPDatabaseReplicationObserver>)observer forReplicationOfDatabase:(MPDatabase *)db;

+ (NSString *)notificationNameForReplicationEventType:(MPReplicationEventType)eventType;

- (void)postNotificationForSharingManagedObject:(MPManagedObject *)obj;

- (void)addManagedObjectSharingObserver:(id<MPManagedObjectSharingObserver>)observer;

@end


/** A MPManagedObject related utility category on NSNotification.  */
@interface NSNotification (MPManagedObjectExtensions)
- (MPManagedObject *)managedObject; // shorthand for casting notification.object and checking its type
@end

#pragma mark -
#pragma mark Concrete database & MO change observer protocols

/** A utility protocol which helps guarantee correctness of observing replication completion notifications emitted by databases. If you call -addObserver:forReplicationOfDatabase: in a class implementation, have the class conform to MPDatabaseReplicationObserver. */
@protocol MPDatabaseReplicationObserver <NSObject>
- (void)didCompletePersistentPullReplication:(NSNotification *)notification;
- (void)didCompletePersistentPushReplication:(NSNotification *)notification;
- (void)didUpdateProgressOfPersistentPullReplication:(NSNotification *)notification;
- (void)didUpdateProgressOfPersistentPushReplication:(NSNotification *)notification;
@end

@protocol MPManagedObjectSharingObserver <NSObject>
- (void)didShareManagedObject:(NSNotification *)notification;
@end

@protocol MPObjectSelectionObserver <NSObject>
@optional // marked optional because of some MPSaveableMixin implementation details.
- (void)didChangeMasterSelectionToSingleObject:(NSNotification *)notification;
- (void)didChangeDetailSelectionToSingleObject:(NSNotification *)notification;
- (void)didChangeMasterSelectionToMultipleObjects:(NSNotification *)notification;
- (void)didChangeDetailSelectionToMultipleObjects:(NSNotification *)notification;
@end