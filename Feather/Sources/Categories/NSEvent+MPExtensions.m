//
//  NSEvent+MPExtensions.m
//  Manuscripts
//
//  Created by Matias Piipari on 20/04/2013.
//  Copyright (c) 2013-2015 Manuscripts.app Limited. All rights reserved.
//

#import "NSEvent+MPExtensions.h"

@implementation NSEvent (MPExtensions)

+ (BOOL)commandKeyDown
{
    return ([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask) == NSCommandKeyMask;
}

+ (BOOL)optionKeyDown
{
    return ([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask) == NSAlternateKeyMask;
}

+ (BOOL)shiftKeyDown
{
    CGEventRef event = CGEventCreate(NULL);
    CGEventFlags mods = CGEventGetFlags(event);
    BOOL retVal = (mods & kCGEventFlagMaskShift ? YES : NO);
    CFRelease(event);
    return retVal;
}

@end
