//
//  NSImage+MPExtensions.h
//  Feather
//
//  Created by Matias Piipari on 13/04/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import <Cocoa/Cocoa.h>

const NSUInteger MPEMUsPerInch = 914400;


// EMU size is WordML terminology.
typedef struct MPEMUSize
{
    NSUInteger width;
    NSUInteger height;
} MPEMUSize;

@interface NSImage (MPExtensions)

- (NSImage *)roundCornersImageCornerRadius:(NSInteger)radius;

@property (readonly) CGImageRef CGImage;

+ (NSImage *)imageForURL:(NSURL *)imageURL;
- (NSUInteger)DPI;
- (MPEMUSize)EMUSize;

@end

// Kindly contributed by Charles Parnot (FDFoundation)
@interface NSImage (FDImageDiff)

- (BOOL)isPixelEqualToImage:(NSImage *)image;

- (CGFloat)pixelDifferenceWithImage:(NSImage *)image;

@end