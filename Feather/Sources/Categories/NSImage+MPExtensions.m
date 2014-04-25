//
//  NSImage+MPExtensions.m
//  Feather
//
//  Created by Matias Piipari on 13/04/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import "NSImage+MPExtensions.h"

@implementation NSImage (RoundCorner)

void addRoundedRectToPath(CGContextRef context, CGRect rect, float ovalWidth, float ovalHeight)
{
    float fw, fh;
    if (ovalWidth == 0 || ovalHeight == 0) {
        CGContextAddRect(context, rect);
        return;
    }
    CGContextSaveGState(context);
    CGContextTranslateCTM (context, CGRectGetMinX(rect), CGRectGetMinY(rect));
    CGContextScaleCTM (context, ovalWidth, ovalHeight);
    fw = CGRectGetWidth (rect) / ovalWidth;
    fh = CGRectGetHeight (rect) / ovalHeight;
    CGContextMoveToPoint(context, fw, fh/2);
    CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);
    CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1);
    CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1);
    CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1);
    CGContextClosePath(context);
    CGContextRestoreGState(context);
}

- (NSImage *)roundCornersImageCornerRadius:(NSInteger)radius
{
    int w = (int) self.size.width;
    int h = (int) self.size.height;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, w, h, 8, 4 * w, colorSpace, kCGImageAlphaPremultipliedFirst);
    
    CGContextBeginPath(context);
    CGRect rect = CGRectMake(0, 0, w, h);
    addRoundedRectToPath(context, rect, radius, radius);
    CGContextClosePath(context);
    CGContextClip(context);
    
    CGImageRef cgImage = [[NSBitmapImageRep imageRepWithData:[self TIFFRepresentation]] CGImage];
    
    CGContextDrawImage(context, CGRectMake(0, 0, w, h), cgImage);
    
    CGImageRef imageMasked = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    NSImage *tmpImage = [[NSImage alloc] initWithCGImage:imageMasked size:self.size];
    NSData *imageData = [tmpImage TIFFRepresentation];
    NSImage *image = [[NSImage alloc] initWithData:imageData];
    
    return image;
}

- (CGImageRef)CGImage
{
    CGImageRef imageRef = [self CGImageForProposedRect:NULL context:NULL hints:NULL];
    return imageRef;
}

@end

@implementation NSImage (FDImageDiff)

- (BOOL)isPixelEqualToImage:(NSImage *)image
{
    CFDataRef data1 = CGDataProviderCopyData(CGImageGetDataProvider(self.CGImage));
    CFDataRef data2 = CGDataProviderCopyData(CGImageGetDataProvider(image.CGImage));
    
    BOOL result = NO;
    if (data1 == NULL && data2 == NULL)
        result = YES;
    else if (data1 == NULL || data2 == NULL)
        result = NO;
    else
        result = CFEqual(data1, data2);
    
    if (data1)
        CFRelease(data1);
    if (data2)
        CFRelease(data2);
    return result;
}

- (CGFloat)pixelDifferenceWithImage:(NSImage *)image
{
    if (image == nil)
        return 1.0;
    
    CFDataRef data1 = CGDataProviderCopyData(CGImageGetDataProvider([self CGImage]));
    CFDataRef data2 = CGDataProviderCopyData(CGImageGetDataProvider([image CGImage]));
    
    CGFloat result = 1.0;
    if (data1 == NULL && data2 == NULL)
        result = 0.0;
    else if (data1 == NULL || data2 == NULL)
        result = 1.0;
    else if (CFDataGetLength(data1) != CFDataGetLength(data2))
        result = 1.0;
    else
    {
        const UInt8 *bytes1 = CFDataGetBytePtr(data1);
        const UInt8 *bytes2 = CFDataGetBytePtr(data2);
        NSUInteger length = CFDataGetLength(data1);
        NSUInteger diff = 0;
        for (NSUInteger i = 0; i < length; i++)
            diff += abs((int)(bytes1[i]) - (int)(bytes2[i]));
        diff /= length;
        result = (CGFloat)diff / (CGFloat)0xFF;
    }
    
    if (data1)
        CFRelease(data1);
    if (data2)
        CFRelease(data2);
    return result;
}

@end
