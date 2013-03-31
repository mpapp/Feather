//
//  MPContributor.m
//  Manuscripts
//
//  Created by Matias Piipari on 21/09/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
//

#import "MPContributor.h"
#import "MPContributorsController.h"

#import <CouchCocoa/CouchCocoa.h>

@implementation MPContributor
@dynamic category, role;

// FIXME: Make abstract method in an abstract base class.
#ifndef MPAPP
@dynamic fullName;
#endif


- (NSImage *)thumbnailImage { NSImage *img = [NSImage imageNamed:@"face-monkey.png"]; [img setTemplate:YES]; return img;  }

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