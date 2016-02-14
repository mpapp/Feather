//
//  MPRootSection.m
//  Manuscripts
//
//  Created by Matias Piipari on 19/12/2012.
//  Copyright (c) 2015 Manuscripts.app Limited. All rights reserved.
//

#import "MPRootSection.h"
#import "MPRootSection+Protected.h"

@import FeatherExtensions;
#import <Feather/MPDatabasePackageController.h>
#import <RegexKitLite/RegexKitLiteFramework.h>
#import "Mixin.h"

#import <Feather/MPVirtualSection.h>
#import <Feather/MPCacheableMixin.h>

NSString *const MPPasteboardTypeRootSection = @"com.piipari.root-section.id.plist";

@implementation MPRootSection

@synthesize inEditMode;

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

+ (BOOL)hasMainThreadIsolatedCachedProperties {
    return YES; // UI oriented caches.
}

+ (Class)managedObjectClass
{
    NSString *className = [NSStringFromClass(self) stringByReplacingOccurrencesOfRegex:@"RootSection$"
                                                                             withString:@""];
    
    Class class = NSClassFromString(className);
    NSAssert([class isSubclassOfClass:[MPManagedObject class]], @"%@ is not a subclass of MPManagedObject.", class);
    
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

- (void)hasAddedManagedObject:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self clearCachedValues];
    });
}

- (void)hasUpdatedManagedObject:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self clearCachedValues];
    });
}

- (void)hasRemovedManagedObject:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self clearCachedValues];
    });
}

- (void)dealloc
{
    // Commented out on 2013-01-22 as unnecessary (as discussed with Matias): the package controller's dealloc may already have destroyed the notification center by this point -- @2pii
    //assert([self.packageController notificationCenter]);
    NSNotificationCenter *nc = [self.packageController notificationCenter];
    [nc removeObserver:self];
}

- (void)setTitle:(NSString *)title {
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd];
}

- (NSString *)title {
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd];
    return nil;
}

- (void)setDesc:(NSString *)desc {
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd];
}

- (NSString *)desc {
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd];
}

- (void)setSubtitle:(NSString *)subtitle {
    @throw [MPAbstractMethodException exceptionWithSelector:_cmd];
}

- (NSString *)subtitle {
    return @"";
}

- (NSString *)identifier {
    return nil;
}

- (id<MPTreeItem>)parent {
    return nil;
}

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

- (BOOL)save
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
    //[img setTemplate:YES];
    return img;
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

- (Class)representedObjectClass
{
    NSString *className = NSStringFromClass([self class]);
    NSString *representedClassName =
        [className stringByReplacingOccurrencesOfRegex:@"RootSection$" withString:@""];
    Class representedClass = NSClassFromString(representedClassName);
    NSAssert(representedClass, @"Could not resolve represented class for %@ (%@)", self, self.class);
    return representedClass;
}

- (void)refreshCachedValues {}

#pragma mark - Pasteboard

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard {
    return @[MPPasteboardTypeRootSection];
}

- (id)pasteboardPropertyListForType:(NSString *)type {
    NSDictionary *dict = @{
                           @"databasePackageID":self.packageController.fullyQualifiedIdentifier,
                           @"objectType":NSStringFromClass(self.class)
                        };
    
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict
                                                              format:NSPropertyListXMLFormat_v1_0
                                                             options:0
                                                               error:&error];
    NSAssert(data, @"Failed to create plist representation of a root section: %@", error);
    
    return data;
}

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard {
    return @[MPPasteboardTypeRootSection];
}

- (id)initWithPasteboardPropertyList:(id)propertyList ofType:(NSString *)type {
    self = [super init];
    
    if (self) {
        if (![type isEqualToString:MPPasteboardTypeRootSection]) {
            self = nil;
            return self;
        }
        
        NSPropertyListFormat format;
        NSError *err = nil;
        NSDictionary *dict = [NSPropertyListSerialization propertyListWithData:propertyList
                                                                       options:0
                                                                        format:&format
                                                                         error:&err];
        if (!dict) {
            self = nil;
            return self;
        }
        
        NSString *databasePackageID = dict[@"databasePackageID"];
        
        MPDatabasePackageController *pkgc = (id)[MPDatabasePackageController databasePackageControllerWithFullyQualifiedIdentifier:databasePackageID];
        
        NSSet *rootSectionClasses = [NSSet setWithArray:[pkgc.rootSections valueForKey:@"class"]];
        NSAssert(rootSectionClasses.count == pkgc.rootSections.count,
                 @"Expecting for root sections to be unique by their class, but they're not: %@", rootSectionClasses);
        
        MPRootSection *rs = [pkgc.rootSections firstObjectMatching:^BOOL(MPRootSection *s) {
            return [s isKindOfClass:self.class];
        }];
        
        if (!rs) {
            self = nil;
            return self;
        }
        
        return rs;
    }
    
    return self;
}

+ (id)objectWithReferableDictionaryRepresentation:(NSDictionary *)referableDictionaryRep {
    NSString *packageID = referableDictionaryRep[@"databasePackageID"];
    
    if (!packageID)
        return nil;
    
    NSString *objectType = referableDictionaryRep[@"objectType"];
    
    if (!objectType)
        return nil;
    
    MPDatabasePackageController *pkgc
        = [MPDatabasePackageController databasePackageControllerWithFullyQualifiedIdentifier:packageID];
    
    Class class = NSClassFromString(objectType);
    
    MPRootSection *rs = [pkgc.rootSections firstObjectMatching:^BOOL(MPRootSection *rootSection) {
        return [rootSection.class isSubclassOfClass:class];
    }];
    
    return rs;
}

@end