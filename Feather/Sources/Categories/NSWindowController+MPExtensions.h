//
//  NSWindow+MPExtensions.h
//  Manuscripts
//
//  Created by Markus on 2/5/13.
//  Copyright (c) 2013-2015 Manuscripts.app Limited. All rights reserved.
//


#import <Cocoa/Cocoa.h>


#define MPNilToNibNameFromClass(nibName, klass) ((nibName == nil) ? NSStringFromClass(klass) : nibName)


@protocol MPWindowControllerAwareViewController <NSObject>
@property (strong) NSWindowController *windowController;
@end


@protocol MPContentViewControllerAwareWindowController <NSObject>
@property (weak) NSViewController *contentViewController;
@end


@interface NSWindowController (MPExtensions)

+ (id)windowControllerOfClass:(Class)windowControllerClass
               windowNibNamed:(NSString *)windowNibName
        contentViewController:(NSViewController *)contentViewController;

+ (id)windowControllerOfClass:(Class)windowControllerClass
               windowNibNamed:(NSString *)windowNibName
        contentViewController:(NSViewController *__autoreleasing *)viewController
                      ofClass:(Class)contentViewControllerClass
          contentViewNibNamed:(NSString *)contentViewNibName;

@end
