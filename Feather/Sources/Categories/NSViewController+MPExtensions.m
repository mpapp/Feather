//
//  NSViewController+MPExtensions.m
//  Manuscripts
//
//  Created by Markus on 2/5/13.
//  Copyright (c) 2013-2015 Manuscripts.app Limited. All rights reserved.
//


#import "NSViewController+MPExtensions.h"
#import "NSWindowController+MPExtensions.h"


@implementation NSViewController (MPExtensions)

+ (instancetype)viewControllerOfClass:(Class)viewControllerClass
                         withNibNamed:(NSString *)nibName
{
    NSViewController *vc = [[viewControllerClass alloc] initWithNibName:MPNilToNibNameFromClass(nibName, viewControllerClass) bundle:nil];
    return vc;
}

@end
