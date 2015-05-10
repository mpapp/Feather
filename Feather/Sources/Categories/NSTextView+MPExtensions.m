//
//  NSTextView+MPExtensions.m
//  Manuscripts
//
//  Created by Matias Piipari on 21/04/2014.
//  Copyright (c) 2014-2015 Manuscripts.app Limited. All rights reserved.
//

#import "NSTextView+MPExtensions.h"

@implementation NSTextView (MPExtensions)

- (NSUInteger)wrappedLineCount
{
    NSLayoutManager *layoutManager = [self layoutManager];
    assert(layoutManager);
    
    NSUInteger numberOfLines = 0, index = 0;
    NSUInteger numberOfGlyphs = [layoutManager numberOfGlyphs];
    
    NSRange lineRange;
    for (numberOfLines = 0, index = 0; index < numberOfGlyphs; numberOfLines++){
        (void) [layoutManager lineFragmentRectForGlyphAtIndex:index
                                               effectiveRange:&lineRange];
        index = NSMaxRange(lineRange);
    }
    return numberOfLines;
}

- (NSUInteger)hardLineFeedCount
{
    NSString *string = self.string;
    NSUInteger numberOfLines = 0, index = 0, stringLength = [string length];
    for (index = 0, numberOfLines = 0; index < stringLength; numberOfLines++)
        index = NSMaxRange([string lineRangeForRange:NSMakeRange(index, 0)]);
    return numberOfLines;
}

@end