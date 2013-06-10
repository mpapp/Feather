//
//  NSTextField+MPExtensions.m
//  Feather
//
//  Created by Markus on 1.6.2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//


#import "NSTextField+MPExtensions.h"
#import "NSView+MPExtensions.h"


@implementation NSTextField (MPExtensions)

- (void)applyMinimumSizeForMaximumWidth:(CGFloat)maximumWidth
{
    NSLayoutConstraint *wc = self.widthConstraint; assert(wc);
    NSLayoutConstraint *hc = self.heightConstraint; assert(hc);
    
    NSSize sz = [self minimumSizeForMaximumWidth:maximumWidth];
    wc.constant = sz.width;
    hc.constant = sz.height;
}

- (NSSize)minimumSizeForMaximumWidth:(CGFloat)maximumWidth
{
    CGFloat minimumHeight = [self.cell cellSizeForBounds:NSMakeRect(0.0, 0.0, CGFLOAT_MAX, CGFLOAT_MAX)].height;
    
    NSSize sz = NSZeroSize;
    CGFloat height = 0.0;
    
    do {
        height += minimumHeight;
        sz = [self.cell cellSizeForBounds:NSMakeRect(0.0, 0.0, maximumWidth, height)];
    } while (sz.height >= height);
    
    sz = [self.cell cellSizeForBounds:NSMakeRect(0.0, 0.0, maximumWidth, sz.height)];
    return sz;
}

@end

