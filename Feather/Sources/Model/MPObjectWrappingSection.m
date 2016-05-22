//
//  MPObjectWrappingSection.m
//  Feather
//
//  Created by Matias Piipari on 19/05/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

#import <Feather/Feather-Swift.h>

#import "MPObjectWrappingSection.h"
#import "MPVirtualSection+Protected.h"

#import "MPException.h"
#import "MPManagedObject.h"
#import "MPManagedObjectsController.h"
#import "MPDatabasePackageController.h"

#import <FeatherExtensions/FeatherExtensions.h>

@interface MPObjectWrappingSection () {
}
@end

@implementation MPObjectWrappingSection
@synthesize identifier = _identifier;

- (instancetype)initWithPackageController:(MPDatabasePackageController *)pkgController {
    @throw [[MPInitIsPrivateException alloc] initWithSelector:_cmd];
}

- (instancetype)initWithParent:(id<MPTreeItem>)parentItem
                 wrappedObject:(MPManagedObject<MPTitledProtocol,MPPlaceHolding, MPThumbnailable, MPTreeItem> *)obj
                    identifier:(NSString *)theIdentifier {
    return [self initWithParent:parentItem wrappedObject:obj representedObjects:@[ obj ] identifier:theIdentifier representedObjectClass:obj.class observedManagedObjectClasses:nil];
}

- (instancetype)initWithParent:(id<MPTreeItem>)parentItem
                 wrappedObject:(MPManagedObject<MPTitledProtocol, MPPlaceHolding, MPThumbnailable, MPTreeItem> *)obj
            representedObjects:(NSArray *)representedObjects
                    identifier:(NSString *)theIdentifier
        representedObjectClass:(Class)representedObjectClass
  observedManagedObjectClasses:(NSArray *)additionalObservedManagedObjectClasses {
    NSAssert(parentItem, @"Attempting to create object wrapping section with nil parent to wrap (%@)", obj);
    NSAssert(parentItem.packageController, @"Attempting to create object wrapping section with a parent with no package controller (%@)", parentItem);
    NSAssert(obj, @"Attempting to create an object wrapping section with a nil obejct for parent %@", parentItem);
    NSAssert([[obj class] isSubclassOfClass:[MPManagedObject class]], @"Unexpected type: %@.", [obj class]);

    if (self = [super initWithPackageController:parentItem.packageController parent:parentItem identifier:theIdentifier])
    {
        _wrappedObject = obj;
        
        _representedObjects = representedObjects;
        
        NSParameterAssert(theIdentifier);
        self.identifier = theIdentifier;
        
        _managedObjectClass = representedObjectClass;
        _observedManagedObjectClasses = additionalObservedManagedObjectClasses;
        
        
        [self observeManagedObjectChanges];
    }
    
    return self;
}

- (void)setRepresentedObjects:(NSArray *)representedObjects { _representedObjects = representedObjects; }
- (NSArray *)representedObjects { return _representedObjects; }

- (NSString *)title { return _wrappedObject.title ? _wrappedObject.title : @""; }

- (NSImage *)thumbnailImage
{
    return [_wrappedObject thumbnailImage];
}

- (NSString *)placeholderString {
    return _wrappedObject.placeholderString;
}
- (BOOL)isEditable {
    return YES;
}

- (BOOL)save:(NSError **)err
{
    return [_wrappedObject save:err];
}

- (BOOL)isEqual:(id)object {
    if (![self isKindOfClass:object]) {
        return NO;
    }
    return [self.wrappedObject isEqual:[object wrappedObject]];
}

- (NSUInteger)hash {
    return self.wrappedObject.hash;
}

- (NSArray *)children {
    return self.wrappedChildren;
}

+ (NSArray *)arrayOfWrappedObjects:(NSArray *)wrappedObjects
                        withParent:(id<MPTreeItem>)parent
                  identifierPrefix:(NSString *)identifierPrefix {
    // the package controller property should be the same for the parent and all the wrapped objects
    if (wrappedObjects.count > 0)
        [[wrappedObjects valueForKey:@"controller"] matchingValueForKey:@"packageController" value:^(BOOL valueMatches, id value) {
             NSParameterAssert(valueMatches);
             NSParameterAssert(value != nil);
             NSParameterAssert(value == parent.packageController);
         }];
    
    return [wrappedObjects mapObjectsUsingBlock:^id(MPManagedObject<MPTitledProtocol, MPPlaceHolding, MPTreeItem> *o, NSUInteger idx) {
        NSParameterAssert([o identifier]);
        NSString *identifier = [NSString stringWithFormat:@"%@-%@", identifierPrefix, [o identifier]];
        MPObjectWrappingSection *wrappedO = [[MPObjectWrappingSection alloc] initWithParent:parent wrappedObject:o identifier:identifier];
        wrappedO = (id)[[o.controller.packageController treeItemPool] itemForItem:wrappedO];
        return wrappedO;
    }];
}

- (void)observeManagedObjectChanges
{
    [super observeManagedObjectChanges];
    
    for (Class cls in _observedManagedObjectClasses)
    {
        assert([cls isSubclassOfClass:[MPManagedObject class]]);
        assert(self.packageController);
        
        [[self.packageController notificationCenter] addPastChangeObserver:self forManagedObjectsOfClass:cls
                                                                    didAdd:
         ^(id<MPManagedObjectChangeObserver, MPCacheable> _self, NSNotification *notification)
         {
         } didUpdate:
         ^(id<MPManagedObjectChangeObserver, MPCacheable> _self, NSNotification *notification)
         {
         } didRemove:^(id<MPManagedObjectChangeObserver, MPCacheable> _self, NSNotification *notification)
         {
         }];
    }
}

- (void)setRepresentedObjectClass:(Class)representedObjectClass {
    _managedObjectClass = representedObjectClass;
    
    // refresh object observing.
    [[self.packageController notificationCenter] removeObserver:self];
    [self observeManagedObjectChanges];
}

- (Class)representedObjectClass {
    return _managedObjectClass;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<MPObjectWrappingSection identifier:%@ title:%@ wrappedObject:%@ wrappedChildren:%@>",
                                      self.identifier, self.title, self.wrappedObject, self.wrappedChildren];
}

@end
