//
//  NSPopover+MPExtensions.h
//  Manuscripts
//
//  Created by Markus on 2/6/13.
//  Copyright (c) 2013-2015 Manuscripts.app Limited. All rights reserved.
//


#import <Cocoa/Cocoa.h>


@interface NSPopover (MPExtensions)

+ (NSPopover *) popoverWithContentViewController:(NSViewController *)contentViewController;

+ (NSPopover *) popoverWithContentViewControllerOfClass:(Class)contentViewControllerClass
                                    contentViewNibNamed:(NSString *)nibName;

- (void) showRelativeToView:(NSView *)view edge:(NSRectEdge)edge;
- (void) showAboveView:(NSView *)view;
- (void) showBelowView:(NSView *)view;
- (void) showToTheLeftOfView:(NSView *)view;
- (void) showToTheRightOfView:(NSView *)view;

@end
