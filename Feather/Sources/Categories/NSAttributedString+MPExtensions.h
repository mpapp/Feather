//
//  NSAttributedString+MPExtensions.h
//  Feather
//
//  Created by Matias Piipari on 12/04/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern int gNSStringGeometricsTypesetterBehavior;

@interface NSAttributedString (MPExtensions)

// Measuring Attributed Strings
- (NSSize)sizeForWidth:(float)width height:(float)height;
- (float)heightForWidth:(float)width;
- (float)widthForHeight:(float)height;

@end

/**
 * Derived from https://github.com/onecrayon/ShellActions-sugar/blob/master/ShellActions/Third%20Party/NS(Attributed)String%2BGeometrics.h
 */
@interface NSString (MPExtensions)

// Measuring a String With Attributes
- (NSSize)sizeForWidth:(float)width height:(float)height attributes:(NSDictionary*)attributes;
- (float)heightForWidth:(float)width attributes:(NSDictionary*)attributes;
- (float)widthForHeight:(float)height attributes:(NSDictionary*)attributes;

// Measuring a String with a constant Font
- (NSSize)sizeForWidth:(float)width height:(float)height font:(NSFont*)font;
- (float)heightForWidth:(float)width font:(NSFont*)font;
- (float)widthForHeight:(float)height font:(NSFont*)font;

@end