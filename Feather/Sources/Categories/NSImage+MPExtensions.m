//
//  NSImage+MPExtensions.m
//  Feather
//
//  Created by Matias Piipari on 13/04/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import "NSImage+MPExtensions.h"

#define RGB(R,G,B) [NSColor colorWithCalibratedRed:(R)/255. green:(G)/255. blue:(B)/255. alpha:1]
#define RGBA(R,G,B,A) [NSColor colorWithCalibratedRed:(R)/255. green:(G)/255. blue:(B)/255. alpha:(A)]

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
    CGImageRelease(imageMasked);
    
    NSData *imageData = [tmpImage TIFFRepresentation];
    NSImage *image = [[NSImage alloc] initWithData:imageData];
    
    return image;
}

- (NSImage *)framedWithSize:(NSSize)size {
    // margin for frame
    float margin = 3;
    float marginForShadow = 3;
    // radius of frame corners
    float frameRadius = 2;
    
    // rectangle of whole view
    NSRect fullRect;
    fullRect = NSZeroRect;
    fullRect.size = size;
    float coef = MIN(size.height / self.size.height,
                     size.width / self.size.width);
    fullRect.size = self.size;
    fullRect.size.height *= coef;
    fullRect.size.width *= coef;
    
    NSImage *img = [[NSImage alloc] initWithSize:fullRect.size];
    [img lockFocus];
    {
        // rectangle for frame which is margined
        NSRect frameRect = fullRect;
        frameRect.size.height -= margin * 2 + marginForShadow;
        frameRect.size.width -= margin * 2 + marginForShadow;
        frameRect.origin.x += margin;
        frameRect.origin.y += margin;
        
        // width of frame should be 5% of ave(height, width) of picture
        float frameSize = 0.05 * (frameRect.size.height + frameRect.size.width) / 2;
        
        // draw frame with small radius corners
        NSBezierPath *framePath = [NSBezierPath bezierPathWithRoundedRect:frameRect xRadius:frameRadius yRadius:frameRadius];
        
        // we need shadow on both frame and picture
        NSShadow *shadow = [[NSShadow alloc] init];
        [shadow setShadowColor:RGBA(40, 40, 40, 0.7)];
        [shadow setShadowOffset:NSMakeSize(3.1, -3.1)];
        [shadow setShadowBlurRadius:5];
        
        [NSGraphicsContext saveGraphicsState];
        [shadow set];
        
        // draw frame
        [[NSColor whiteColor] setFill];
        [framePath fill];
        [NSGraphicsContext restoreGraphicsState];
        
        // rectangle of actual picture
        NSRect pictureRect = frameRect;
        pictureRect.size.height -= frameSize * 2;
        pictureRect.size.width -= frameSize * 2;
        pictureRect.origin.x += frameSize;
        pictureRect.origin.y += frameSize;
        
        // draw picture in frame with shadow and gray stroke
        NSBezierPath *picturePath = [NSBezierPath bezierPathWithRoundedRect:pictureRect xRadius:frameRadius yRadius:frameRadius];
        [RGB(240, 240, 240) set];
        [picturePath stroke];
        
        [NSGraphicsContext saveGraphicsState];
        [shadow setShadowOffset:NSZeroSize];
        [shadow set];
        [self drawInRect:pictureRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1 respectFlipped:YES hints:nil];
        [NSGraphicsContext restoreGraphicsState];
    }
    [img unlockFocus];
    
    return img;
}

- (CGImageRef)CGImage
{
    CGImageRef imageRef = [self CGImageForProposedRect:NULL context:NULL hints:NULL];
    return imageRef;
}

- (BOOL)writeToFile:(NSString *)path
            options:(NSDataWritingOptions)options
               type:(NSBitmapImageFileType)type
              error:(NSError **)error {
    
    CGImageRef cgRef = [self CGImageForProposedRect:NULL context:nil hints:nil];
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
    
    if (!newRep) {
        if (error)
            *error = [NSError errorWithDomain:@"MPExtensionsErrorDomain"
                                         code:MPImageExtensionsErrorCodeFailedToCreateRepresentation
                                     userInfo:@{NSLocalizedDescriptionKey : @"Failed to create bitmap image representation"}];
        return NO;
    }
    
    newRep.size = self.size;   // if you want the same resolution
    
    NSData *pngData = [newRep representationUsingType:NSPNGFileType properties:nil];
    return [pngData writeToFile:path options:options error:error];
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
        
        if (length > 0)
            diff /= length;
        
        result = (CGFloat)diff / (CGFloat)0xFF;
    }
    
    if (data1)
        CFRelease(data1);
    if (data2)
        CFRelease(data2);
    return result;
}

+ (NSImage *)imageForURL:(NSURL *)imageURL
{
    return [[NSImage alloc] initByReferencingURL:imageURL];
}

- (NSImageRep *)rep
{
    if (self.representations.count > 0)
        return self.representations[0];
    return nil;
}

- (NSUInteger)DPI
{
    return (72.0 * self.rep.pixelsWide) / self.size.width;
}

- (MPEMUSize)EMUSize
{
    MPEMUSize size = {.width=0, .height=0};
    NSUInteger DPI = self.DPI;
    
    if (DPI > 0)
    {
        size.width = MPEMUsPerInch * self.size.width / DPI;
        size.height = MPEMUsPerInch * self.size.height / DPI;
    }
    
    return size;
}

+ (NSUInteger)bitmapImageTypeForData:(NSData *)data {
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    NSString *type = (__bridge NSString *)CGImageSourceGetType(source);
    
    if ([type isEqualToString:(__bridge NSString *)kUTTypePNG])
        return NSPNGFileType;
    
    if ([type isEqualToString:(__bridge NSString *)kUTTypeTIFF])
        return NSTIFFFileType;
    
    if ([type isEqualToString:(__bridge NSString *)kUTTypeJPEG])
        return NSJPEGFileType;
    
    if ([type isEqualToString:(__bridge NSString *)kUTTypeJPEG2000])
        return NSJPEG2000FileType;
    
    if ([type isEqualToString:(__bridge NSString *)kUTTypeBMP])
        return NSBMPFileType;
    
    CFRelease(source);
    return NSNotFound;
}

+ (NSArray *)prioritizedImageDataPasteboardTypes {
    return @[(__bridge NSString *)kUTTypePDF,
             (__bridge NSString *)kUTTypePNG,
             (__bridge NSString *)kUTTypeJPEG,
             (__bridge NSString *)kUTTypeTIFF,
             (__bridge NSString *)kUTTypeBMP,
             (__bridge NSString *)kUTTypeJPEG2000];
}

+ (NSImage *)imageFromPasteboard:(NSPasteboard *)pasteboard pasteboardType:(NSString **)type {
    for (NSString *t in [self prioritizedImageDataPasteboardTypes]) {
        NSData *data = [pasteboard dataForType:t];
        if (data) {
            if (type)
                *type = t;
            
            return [[NSImage alloc] initWithData:data];
        }
    }
    
    return nil;
}

+ (NSUInteger)bitmapImageFileTypeForPasteboardType:(NSString *)pasteboardType {
    if ([pasteboardType isEqualToString:(__bridge NSString *)kUTTypePNG] || [pasteboardType isEqualToString:@"Apple PNG pasteboard type"]) {
        return NSPNGFileType;
    }
    if ([pasteboardType isEqualToString:(__bridge NSString *)kUTTypeTIFF] || [pasteboardType isEqualToString:@"NeXT TIFF v4.0 pasteboard type"]) {
        return NSPNGFileType;
    }
    if ([pasteboardType isEqualToString:(__bridge NSString *)kUTTypeJPEG]) {
        return NSJPEGFileType;
    }
    if ([pasteboardType isEqualToString:(__bridge NSString *)kUTTypeJPEG2000]) {
        return NSJPEG2000FileType;
    }
    if ([pasteboardType isEqualToString:(__bridge NSString *)kUTTypeBMP]) {
        return NSBMPFileType;
    }
    
    return NSNotFound;
}

@end
