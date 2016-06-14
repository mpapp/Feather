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
@synthesize identifier = _identifier;

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

- (instancetype)initWithPackageController:(MPDatabasePackageController *)pkgController parent:(id<MPTreeItem>)parent identifier:(nonnull NSString *)identifier
{
    NSParameterAssert([NSThread isMainThread]);
    
    if (self = [super init])
    {
        assert(pkgController);
        _packageController = pkgController;
        
        assert(parent);
        _parent = parent;
        
        NSParameterAssert(identifier);
        _identifier = identifier;
        
        // some subclasses get a non-null managedObjectClass later during initialisation, hence the if.
        if (self.representedObjectClass)
            [self observeManagedObjectChanges];
    }
    
    return self;
}

- (void)observeManagedObjectChanges
{
    if (self.representedObjectClass)
        [[(id)_packageController notificationCenter] addPastChangeObserver:self
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
    [[(id)_packageController notificationCenter] removeObserver:self];
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
