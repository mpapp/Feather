//
//  NSMenuItem+MPExtensions.m
//  Feather
//
//  Created by Matias Piipari on 27/04/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

#import "NSMenuItem+MPExtensions.h"
#import "NSAttributedString+MPExtensions.h"

@implementation NSMenuItem (Manuscripts)

+ (NSMenuItem *) menuItemWithTitle:(NSString *)title
                            target:(id)target
                            action:(SEL)action
                 representedObject:(id)representedObject
{
    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title ?: @"" action:action keyEquivalent:@""];
    menuItem.target = target;
    menuItem.representedObject = representedObject;
    return menuItem;
}

+ (NSMenuItem *) menuItemWithTitle:(NSString *)title
                            target:(id)target
                            action:(SEL)action
                       controlSize:(NSControlSize)controlSize
                              bold:(BOOL)bold
                 representedObject:(id)representedObject
{
    NSMenuItem *menuItem = [[NSMenuItem alloc] init];
    menuItem.attributedTitle = [[NSAttributedString alloc] initWithString:title ?: @"" attributes:
                                [NSDictionary textAttributesWithSystemFontOfSize:[NSFont systemFontSizeForControlSize:controlSize] bold:bold]];
    menuItem.target = target;
    menuItem.action = action;
    menuItem.representedObject = representedObject;
    return menuItem;
}

- (BOOL)descendsFromMainMenu {
    NSMenu *parentMenu = self.parentItem.menu;
    NSMenuItem *item = self.parentItem;
    
    do {
        if (parentMenu == [NSApp mainMenu]) {
            return YES;
        }
        
        item = item.parentItem;
        parentMenu = item.menu;
    } while (item);
    
    return NO;
}

@end
