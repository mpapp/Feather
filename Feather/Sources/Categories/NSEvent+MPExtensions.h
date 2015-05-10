//
//  NSEvent+MPExtensions.h
//  Manuscripts
//
//  Created by Matias Piipari on 20/04/2013.
//  Copyright (c) 2013-2015 Manuscripts.app Limited. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// TODO: Move to Feather.

/** NSEvent extensions based on  http://cocoadev.com/wiki/CheckIfCommandKeyIsPressed */
@interface NSEvent (MPExtensions)

+ (BOOL)commandKeyDown;
+ (BOOL)optionKeyDown;
+ (BOOL)shiftKeyDown;

@end
