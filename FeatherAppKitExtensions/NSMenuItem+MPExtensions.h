//
//  NSMenuItem+MPExtensions.h
//  Feather
//
//  Created by Matias Piipari on 27/04/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSMenuItem (Manuscripts)

+ (NSMenuItem *) menuItemWithTitle:(NSString *)title
                            target:(id)target
                            action:(SEL)action
                 representedObject:(id)representedObject;

+ (NSMenuItem *) menuItemWithTitle:(NSString *)title
                            target:(id)target
                            action:(SEL)action
                       controlSize:(NSControlSize)controlSize
                              bold:(BOOL)bold
                 representedObject:(id)representedObject;

/** A menu item descends from the main menu if one can trace a path from its parent menu's parent menu's ... to [NSApp mainMenu] */
@property (readonly) BOOL descendsFromMainMenu;

@end