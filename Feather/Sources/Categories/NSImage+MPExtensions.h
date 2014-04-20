//
//  NSImage+MPExtensions.h
//  Feather
//
//  Created by Matias Piipari on 13/04/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (MPExtensions)

- (NSImage *)roundCornersImageCornerRadius:(NSInteger)radius;

@property (readonly) CGImageRef CGImage;

@end

// Kindly contributed by Charles Parnot (FDFoundation)
@interface NSImage (FDImageDiff)

- (BOOL)isPixelEqualToImage:(NSImage *)image;

- (CGFloat)pixelDifferenceWithImage:(NSImage *)image;

@end