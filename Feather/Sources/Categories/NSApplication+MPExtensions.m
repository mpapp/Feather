//
//  NSApplication+MPExtensions.m
//  Feather
//
//  Created by Matias Piipari on 01/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "NSApplication+MPExtensions.h"

// http://stackoverflow.com/questions/4829529/beginsheet-block-alternative

@implementation NSApplication (SheetAdditions)

- (void)beginSheet:(NSWindow *)sheet modalForWindow:(NSWindow *)docWindow didEndBlock:(void (^)(NSInteger returnCode))block
{
    [docWindow beginSheet:sheet completionHandler:^(NSModalResponse returnCode) {
        block(returnCode);
    }];
}

@end