//
//  MPContributor.m
//  Feather
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPThumbnailable.h"
#import "MPContributor.h"
#import "MPContributorsController.h"

#import <CouchbaseLite/CouchbaseLite.h>

@implementation MPContributor
@dynamic category, role;
@dynamic isCorresponding;

// FIXME: Make abstract method in an abstract base class.
#ifndef MPAPP
@dynamic fullName;
#endif


- (NSImage *)thumbnailImage
{
    NSImage *img = [NSImage imageNamed:@"face-monkey.png"];
    
    #ifdef MP_FEATHER_OSX
    [img setTemplate:YES];
    #endif
    
    return img;
}

- (NSArray *)siblings
{
    assert(self.controller);
    return [(MPContributorsController *)self.controller allContributors];
}

- (NSArray *)children
{
    return @[];
}

- (NSUInteger)childCount
{
    return 0;
}

- (BOOL)hasChildren
{
    return NO;
}

- (id)parent
{
    return nil;
}

- (NSInteger)priority { return [[self getValueOfProperty:@"priority"] integerValue]; }

- (void)setPriority:(NSUInteger)priority { [self setValue:@(priority) ofProperty:@"priority"]; }

- (NSString *)placeholderString
{
    return @"First Last";
}

// FIXME: Make abstract methods in an abstract base class.
#ifndef MPAPP

- (NSComparisonResult)compare:(MPContributor *)contributor
{
    return [self.fullName caseInsensitiveCompare:contributor.fullName];
}
- (void)setTitle:(NSString *)title { [self setFullName:title]; }
- (NSString *)title { return [self fullName] ? [self fullName] : @""; }

#endif


@end
