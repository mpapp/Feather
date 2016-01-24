//
//  MPVirtualSection.m
//  Manuscripts
//
//  Created by Matias Piipari on 13/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Feather/MPVirtualSection.h>
#import "MPVirtualSection+Protected.h"

#import "Mixin.h"

@import FeatherExtensions;

#import <Feather/MPException.h>

@implementation MPVirtualSection

@synthesize inEditMode;

+ (void)initialize
{
    if (self == [MPVirtualSection class])
    {
        [self mixinFrom:[MPCacheableMixin class] followInheritance:NO force:NO];
    }
}

+ (BOOL)hasMainThreadIsolatedCachedProperties {
    return YES; // UI oriented cache.
}

- (instancetype)init
{
    @throw [[MPInitIsPrivateException alloc] initWithSelector:_cmd];
    return nil;
}

- (instancetype)initWithPackageController:(MPDatabasePackageController *)pkgController parent:(id<MPTreeItem>)parent
{
    NSParameterAssert([NSThread isMainThread]);
    
    if (self = [super init])
    {
        assert(pkgController);
        _packageController = pkgController;
        
        assert(parent);
        _parent = parent;
        
        // some subclasses get a non-null managedObjectClass later during initialisation, hence the if.
        if (self.representedObjectClass)
            [self observeManagedObjectChanges];
    }
    
    return self;
}

- (void)observeManagedObjectChanges
{
    if (self.representedObjectClass)
        [[_packageController notificationCenter] addPastChangeObserver:self
                                              forManagedObjectsOfClass:self.representedObjectClass
         didAdd:
         ^(id<MPManagedObjectChangeObserver, MPCacheable> _self, NSNotification *notification)
         {
             
         }
         didUpdate:
         ^(id<MPManagedObjectChangeObserver, MPCacheable> _self, NSNotification *notification)
         {
         }
         didRemove:^(id<MPManagedObjectChangeObserver, MPCacheable> _self, NSNotification *notification)
         {
             
         }];
}

- (void)dealloc {
    NSParameterAssert([NSThread isMainThread]);
    [[_packageController notificationCenter] removeObserver:self];
}

- (void)setTitle:(NSString *)title {
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

- (NSString *)title {
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd]; return nil;
}

- (void)setSubtitle:(NSString *)subtitle {
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

- (NSString *)subtitle {
    return @"";
}

- (void)setDesc:(NSString *)desc {
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

- (NSString *)desc {
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd]; return nil;
}

- (NSArray *)children {
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd]; return nil;
}

- (NSArray *)representedObjects {
    return [self children];
} // synonymous in the base class with -children, subclasses can redefine this.

- (NSUInteger)childCount {
    return self.children.count;
}

- (BOOL)hasChildren {
    return self.childCount > 0;
}

- (NSArray *)siblings {
    return self.parent.children;
}

- (NSInteger)priority {
    return [self.parent.children indexOfObject:self];
}

- (NSString *)identifier {
    return nil;
}

- (BOOL)save
{
    @throw [[MPUnexpectedSelectorException alloc] initWithSelector:_cmd];
    return nil;
}

- (NSString *)thumbnailImageName {
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd];
    return nil;
}
- (NSString *)placeholderString {
    return @"Untitled";
}

- (BOOL)isEditable {
    return NO;
}

- (BOOL)isTitled {
    return YES;
}

- (BOOL)isOptional {
    return NO;
}

- (NSImage *)thumbnailImage
{
    NSImage *img = [NSImage imageNamed:[self thumbnailImageName]];
    //[img setTemplate:YES];
    return img;
}

@end

@implementation MPObjectWrappingSection

- (instancetype)initWithPackageController:(MPDatabasePackageController *)pkgController {
    @throw [[MPInitIsPrivateException alloc] initWithSelector:_cmd];
}

- (instancetype)initWithParent:(id<MPTreeItem>)parentItem
                 wrappedObject:(MPManagedObject<MPTitledProtocol,MPPlaceHolding, MPThumbnailable, MPTreeItem> *)obj {
    return [self initWithParent:parentItem wrappedObject:obj representedObjects:@[ obj ] representedObjectClass:obj.class observedManagedObjectClasses:nil];
}

- (instancetype)initWithParent:(id<MPTreeItem>)parentItem
                 wrappedObject:(MPManagedObject<MPTitledProtocol, MPPlaceHolding, MPThumbnailable, MPTreeItem> *)obj
            representedObjects:(NSArray *)representedObjects
        representedObjectClass:(Class)representedObjectClass
  observedManagedObjectClasses:(NSArray *)additionalObservedManagedObjectClasses {
    assert(parentItem);
    assert(parentItem.packageController);
    
    if (self = [super initWithPackageController:parentItem.packageController parent:parentItem])
    {
        assert(obj);
        _wrappedObject = obj;
        
        _representedObjects = representedObjects;
        
        assert([[obj class] isSubclassOfClass:[MPManagedObject class]]);
        
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

- (NSString *)identifier {
    return nil;
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
                        withParent:(id<MPTreeItem>)parent {
    // the package controller property should be the same for the parent and all the wrapped objects
    if (wrappedObjects.count > 0)
        [[wrappedObjects valueForKey:@"controller"] matchingValueForKey:@"packageController"
                                                                  value:^(BOOL valueMatches, id value)
        {
            NSParameterAssert(valueMatches);
            NSParameterAssert(value != nil);
            NSParameterAssert(value == parent.packageController);
        }];
    
    return [wrappedObjects mapObjectsUsingBlock:^id(MPManagedObject<MPTitledProtocol, MPPlaceHolding> *o, NSUInteger idx)
    {
        return [[MPObjectWrappingSection alloc] initWithParent:parent wrappedObject:o];
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


@end
