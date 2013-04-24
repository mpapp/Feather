//
//  MPRootSection.m
//  Manuscripts
//
//  Created by Matias Piipari on 19/12/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
//

#import "MPRootSection.h"
#import "MPRootSection+Protected.h"

#import <Feather/MPDatabasePackageController.h>
#import "RegexKitLite.h"
#import "Mixin.h"

#import <Feather/MPVirtualSection.h>
#import <Feather/MPCacheableMixin.h>

@implementation MPRootSection

- (instancetype)init
{
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd];
    return nil;
}

+ (void)initialize
{
    if (self == [MPRootSection class])
    {
        [self mixinFrom:[MPCacheableMixin class] followInheritance:NO force:NO];
    }
}

+ (Class)managedObjectClass
{
    NSString *className = [NSStringFromClass(self) stringByReplacingOccurrencesOfRegex:@"RootSection$"
                                                                             withString:@""];
    
    Class class = NSClassFromString(className);
    NSLog(@"Class name is %@, class is %@", className, NSStringFromClass(class));
    assert([class isSubclassOfClass:[MPManagedObject class]]);
    
    return class;
}

- (instancetype)initWithPackageController:(MPDatabasePackageController *)packageController
{
    if ((self = [super init]))
    {
        _packageController = packageController;
        
        NSNotificationCenter *nc = [packageController notificationCenter];
        
        Class moClass = [[self class] managedObjectClass];
        [nc addRecentChangeObserver:self
           forManagedObjectsOfClass:moClass
                           hasAdded:
         ^(MPRootSection *_self, NSNotification *notification)
        { [_self hasAddedManagedObject:notification.object]; }
                        hasUpdated:
         ^(MPRootSection *_self, NSNotification *notification)
        { [_self hasUpdatedManagedObject:notification.object]; }
                        hasRemoved:
         ^(MPRootSection *_self, NSNotification *notification)
        { [_self hasRemovedManagedObject:notification.object]; }];
        
        [self refreshCachedValues];
    }
    
    return self;
}

- (void)hasAddedManagedObject:(NSNotification *)notification { [self clearCachedValues]; }
- (void)hasUpdatedManagedObject:(NSNotification *)notification { [self clearCachedValues]; }
- (void)hasRemovedManagedObject:(NSNotification *)notification { [self clearCachedValues]; }

- (void)dealloc
{
    // Commented out on 2013-01-22 as unnecessary (as discussed with Matias): the package controller's dealloc may already have destroyed the notification center by this point -- @2pii
    //assert([self.packageController notificationCenter]);
    NSNotificationCenter *nc = [self.packageController notificationCenter];
    [nc removeObserver:self];
}

- (void)setTitle:(NSString *)title
{ @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; }

- (NSString *)title
{ @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; return nil; }

- (id<MPTreeItem>)parent
{ return nil; }

- (NSArray *)children
{
    if (!self.cachedChildren)
    {
        [self refreshCachedValues];
    }
    return self.cachedChildren;
}

- (NSArray *)representedObjects
{
    return [self children];
}

- (NSArray *)siblings
{
    assert(_packageController);
    return [_packageController rootSections];
}

- (id)save
{ @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; return nil; }

- (NSUInteger)childCount
{ return [[self children] count]; }

- (BOOL)hasChildren
{ return [self childCount] > 0; }

- (NSInteger)priority
{ @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; return -1; }

- (NSString *)thumbnailImageName
{ @throw [MPAbstractMethodException exceptionWithSelector:_cmd]; return nil; }

- (NSImage *)thumbnailImage
{
    NSImage *img = [NSImage imageNamed:[self thumbnailImageName]];
    [img setTemplate:YES];
    return img;
}

- (BOOL)isEditable { return NO; }

- (Class)representedObjectClass
{
    NSString *className = NSStringFromClass([self class]);
    NSString *representedClassName =
        [className stringByReplacingOccurrencesOfRegex:@"RootSection$" withString:@""];
    Class representedClass = NSClassFromString(representedClassName);
    assert(representedClass);
    return representedClass;
}

- (void)refreshCachedValues {}

@end