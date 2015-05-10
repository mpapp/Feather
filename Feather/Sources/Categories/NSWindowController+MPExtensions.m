//
//  NSWindow+MPExtensions.m
//  Manuscripts
//
//  Created by Markus on 2/5/13.
//  Copyright (c) 2013-2015 Manuscripts.app Limited. All rights reserved.
//


#import "NSWindowController+MPExtensions.h"

#import <FeatherExtensions/FeatherExtensions.h>


static inline void MPLinkWindowControllerAndContentViewController(NSWindowController *wc, NSViewController *vc)
{
    if ([wc conformsToProtocol:@protocol(MPContentViewControllerAwareWindowController)])
    {
        [(id<MPContentViewControllerAwareWindowController>)wc setContentViewController:vc];
    }
    
    if ([vc conformsToProtocol:@protocol(MPWindowControllerAwareViewController)])
    {
        [(id<MPWindowControllerAwareViewController>)vc setWindowController:wc];
    }
}


@implementation NSWindowController (MPExtensions)

+ (id)windowControllerOfClass:(Class)windowControllerClass
               windowNibNamed:(NSString *)windowNibName
        contentViewController:(NSViewController *)contentViewController
{
    NSWindowController *wc = [[windowControllerClass alloc] initWithWindowNibName:MPNilToNibNameFromClass(windowNibName, windowControllerClass)];
    //wc.window.contentView = contentViewController.view;
    
    if (contentViewController)
    {
        [wc.window.contentView addSubviewConstrainedToSuperViewEdges:contentViewController.view];
        MPLinkWindowControllerAndContentViewController(wc, contentViewController);
    }
    
    return wc;
}

+ (id)windowControllerOfClass:(Class)windowControllerClass
               windowNibNamed:(NSString *)windowNibName
        contentViewController:(NSViewController *__autoreleasing *)viewController
                      ofClass:(Class)contentViewControllerClass
          contentViewNibNamed:(NSString *)contentViewNibName
{
    NSWindowController *wc = [[windowControllerClass alloc] initWithWindowNibName:MPNilToNibNameFromClass(windowNibName, windowControllerClass)];
    NSViewController *vc = [[contentViewControllerClass alloc] initWithNibName:MPNilToNibNameFromClass(windowNibName, contentViewControllerClass) bundle:nil];

    if (vc)
    {
        [wc.window.contentView addSubviewConstrainedToSuperViewEdges:vc.view];
        MPLinkWindowControllerAndContentViewController(wc, vc);
    }
    
    if (viewController != NULL)
    {
        *viewController = vc;
    }
    
    return wc;
}

@end
