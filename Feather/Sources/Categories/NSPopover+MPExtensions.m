//
//  NSPopover+MPExtensions.m
//  Manuscripts
//
//  Created by Markus on 2/6/13.
//  Copyright (c) 2013-2015 Manuscripts.app Limited. All rights reserved.
//

#import "NSPopover+MPExtensions.h"
#import <FeatherExtensions/FeatherExtensions.h>

static inline void MPLinkPopoverAndContentViewController(NSPopover *popover, NSViewController *vc)
{
    popover.contentViewController = vc;
    
    if ([vc conformsToProtocol:@protocol(MPPopoverAwareViewController)])
    {
        [(id)vc setPopover:popover];
    }    
}


@implementation NSPopover (MPExtensions)

+ (NSPopover *)popoverWithContentViewController:(NSViewController *)vc
{
    NSPopover *popover = [[NSPopover alloc] init];
    MPLinkPopoverAndContentViewController(popover, vc);
    return popover;
}

+ (NSPopover *)popoverWithContentViewControllerOfClass:(Class)contentViewControllerClass
                                   contentViewNibNamed:(NSString *)nibName
{
    NSPopover *popover = [[NSPopover alloc] init];
    NSViewController *vc = [NSViewController viewControllerOfClass:contentViewControllerClass withNibNamed:nibName];
    MPLinkPopoverAndContentViewController(popover, vc);
    return popover;
}

- (void) showRelativeToView:(NSView *)view edge:(NSRectEdge)edge
{
    [self showRelativeToRect:view.bounds ofView:view preferredEdge:edge];
}

- (void) showAboveView:(NSView *)view
{
    [self showRelativeToView:view edge:NSMaxYEdge];
}

- (void) showBelowView:(NSView *)view
{
    [self showRelativeToView:view edge:NSMinYEdge];
}

- (void) showToTheLeftOfView:(NSView *)view
{
    [self showRelativeToView:view edge:NSMinXEdge];
}

- (void) showToTheRightOfView:(NSView *)view
{
    [self showRelativeToView:view edge:NSMaxXEdge];
}

@end
