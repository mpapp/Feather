//
//  NSApplication+MPExtensions.h
//  Feather
//
//  Created by Matias Piipari on 01/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSApplication (MPExtensions)

- (void)beginSheet:(NSWindow *)sheet modalForWindow:(NSWindow *)docWindow didEndBlock:(void (^)(NSInteger returnCode))block;

@property (readonly) BOOL isSandboxed;
@property (readonly) BOOL isSigned;

@end
