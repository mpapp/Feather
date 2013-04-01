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
    [self beginSheet:sheet
      modalForWindow:docWindow
       modalDelegate:self
      didEndSelector:@selector(my_blockSheetDidEnd:returnCode:contextInfo:)
         contextInfo:(__bridge_retained void *)(block)];
}

- (void)my_blockSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    void (^block)(NSInteger returnCode) = (__bridge void (^)(NSInteger))(contextInfo);
    block(returnCode);
    Block_release(contextInfo);
}

@end