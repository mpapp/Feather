//
//  NSTextField+MPExtensions.h
//  Feather
//
//  Created by Markus on 1.6.2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//


#import <Cocoa/Cocoa.h>


@interface NSTextField (MPExtensions)
- (void)applyMinimumSizeForMaximumWidth:(CGFloat)maximumWidth;
- (NSSize)minimumSizeForMaximumWidth:(CGFloat)maximumWidth;
@end
