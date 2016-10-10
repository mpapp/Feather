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

@import QuickLook;

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

// from http://stackoverflow.com/questions/11949250/how-to-resize-nsimage/38442746#38442746
+ (NSImage *)resizedImage:(NSImage *)sourceImage toPixelDimensions:(NSSize)newSize
{
    if (!sourceImage.isValid)
        return nil;
    
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
                             initWithBitmapDataPlanes:NULL
                             pixelsWide:newSize.width
                             pixelsHigh:newSize.height
                             bitsPerSample:8
                             samplesPerPixel:4
                             hasAlpha:YES
                             isPlanar:NO
                             colorSpaceName:NSCalibratedRGBColorSpace
                             bytesPerRow:0
                             bitsPerPixel:0];
    rep.size = newSize;
    
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
    [sourceImage drawInRect:NSMakeRect(0, 0, newSize.width, newSize.height) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];
    
    NSImage *newImage = [[NSImage alloc] initWithSize:newSize];
    [newImage addRepresentation:rep];
    return newImage;
}

- (CGImageRef)CGImage
{
    CGImageRef imageRef = [self CGImageForProposedRect:NULL context:NULL hints:NULL];
    return imageRef;
}

- (NSData *)imageDataWithOptions:(NSDataWritingOptions)options
                            type:(NSBitmapImageFileType)type
                           error:(NSError **)error {
    CGImageRef cgRef = [self CGImageForProposedRect:NULL context:nil hints:nil];
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
    
    if (!newRep) {
        if (error)
            *error = [NSError errorWithDomain:@"MPExtensionsErrorDomain"
                                         code:MPImageExtensionsErrorCodeFailedToCreateRepresentation
                                     userInfo:@{NSLocalizedDescriptionKey :
                                                    @"Failed to create bitmap image representation"}];
        return nil;
    }
    
    newRep.size = self.size;   // if you want the same resolution
    
    NSData *data = [newRep representationUsingType:type properties:@{}];
    
    return data;
}

- (BOOL)writeToFile:(NSString *)path
            options:(NSDataWritingOptions)options
               type:(NSBitmapImageFileType)type
              error:(NSError **)error {
    NSData *data = [self imageDataWithOptions:options type:type error:error];
    if (!data) {
        return NO;
    }
    return [data writeToFile:path options:options error:error];
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
    NSInteger pixelWidth = self.rep.pixelsWide;
    if (pixelWidth > 0) {
        return (72.0 * pixelWidth) / self.size.width;
    }
    return 72; // PDF images, for example, have zero pixel width
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

- (NSData *)PNGRepresentation {
    [self lockFocus];
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0,
                                                                                               0,
                                                                                               self.size.width,
                                                                                               self.size.height)];
    [self unlockFocus];
    
    return [bitmapRep representationUsingType:NSPNGFileType properties:@{}];
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

+ (NSUInteger)bitmapImageFileTypeForPathExtension:(NSString *)fileExtension {
    NSString *extension = fileExtension.lowercaseString;
    
    if ([@[@"jpg",@"jpeg"] containsObject:extension]) {
        return NSJPEGFileType;
    }
    else if ([@[@"jpg2000",@"jpeg2000"] containsObject:extension]) {
        return NSJPEG2000FileType;
    }
    else if ([@[@"bmp"] containsObject:extension]) {
        return NSBMPFileType;
    }
    else if ([@[@"gif", @"giff"] containsObject:extension]) {
        return NSGIFFileType;
    }
    else if ([@[@"tif",@"tiff"] containsObject:extension]) {
        return NSTIFFFileType;
    }
    else if ([@[@"png"] containsObject:extension]) {
        return NSPNGFileType;
    }
    
    NSAssert(false, @"Unexpected file extension '%@'", fileExtension);
    return NSPNGFileType;
}

+ (NSString *)canonicalPathExtensionForBitmapImageFileType:(NSBitmapImageFileType)fileType {
    switch (fileType) {
        case NSPNGFileType:
            return @"png";
            
        case NSTIFFFileType:
            return @"tiff";
            
        case NSGIFFileType:
            return @"gif";
            
        case NSBMPFileType:
            return @"bmp";
            
        case NSJPEG2000FileType:
            return @"jpeg2000";
            
        case NSJPEGFileType:
            return @"jpeg";
    }
    
    NSAssert(false, @"Unexpected file type: %@", @(fileType));
}

#pragma mark - Previews & thumbnails

// We thank Charles Parnot (https://github.com/cparnot) for donating the image preview & thumbnail code.

+ (NSImage *)imageWithPreviewOfFileAtURL:(NSURL *)url croppedAndScaledToFinalSize:(NSSize)finalSize
{
    CGSize coreGraphicsSize = NSSizeToCGSize(finalSize);
    CFDictionaryRef options = (__bridge CFDictionaryRef)@{(__bridge NSString *)kQLThumbnailOptionIconModeKey: @NO};
    CGImageRef imageRef = QLThumbnailImageCreate(kCFAllocatorDefault, (__bridge CFURLRef)(url), coreGraphicsSize, options);
    
    // now that we know the image proportions, we need to create a larger thumbnail that can be cropped to the final size without empty pixels
    CGSize imageSize = CGSizeMake(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef));
    CGFloat scaleFactor1 = finalSize.width  / imageSize.width;
    CGFloat scaleFactor2 = finalSize.height / imageSize.height;
    CGFloat scaleFactor = fmaxf(scaleFactor1, scaleFactor2);
    if (scaleFactor > 1.0)
    {
        imageSize.width *= scaleFactor;
        imageSize.height *= scaleFactor;
        if (imageRef)
            CFRelease(imageRef);
        imageRef = QLThumbnailImageCreate(kCFAllocatorDefault, (__bridge CFURLRef)(url), imageSize, options);
    }
    
    // CGImageRef --> NSImage
    NSImage *image = nil;
    if (imageRef)
    {
        image = [[NSImage alloc] initWithCGImage:imageRef size:imageSize];
        CFRelease(imageRef);
    }
    
    // fall back on Finder icon and resize
    if (!image)
        image = [[NSWorkspace sharedWorkspace] iconForFile:url.path];
    
    image = [image scaledAndCroppedImageWithFinalSize:finalSize];
    return image;
}

+ (NSImage *)imageWithPreviewOfFileAtURL:(NSURL *)url maxSize:(NSSize)maxSize
{
    CGSize coreGraphicsSize = NSSizeToCGSize(maxSize);
    CFDictionaryRef options = (__bridge CFDictionaryRef)@{(__bridge NSString *)kQLThumbnailOptionIconModeKey: @NO};
    CGImageRef imageRef = QLThumbnailImageCreate(kCFAllocatorDefault, (__bridge CFURLRef)(url), coreGraphicsSize, options);
    
    // CGImageRef --> NSImage
    NSImage *image = nil;
    if (imageRef)
    {
        image = [[NSImage alloc] initWithCGImage:imageRef size:NSMakeSize(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef))];
        CFRelease(imageRef);
    }
    
    // fall back on Finder icon and resize
    else
    {
        image = [[NSWorkspace sharedWorkspace] iconForFile:url.path];
        image = [image scaledImageWithMaxSize:maxSize];
    }
    
    return image;
}

- (NSImage *)scaledImageWithMaxSize:(NSSize)maxSize
{
    if (![self isValid])
        return nil;
    
    // portrait or landscape?
    BOOL portrait = maxSize.width < maxSize.height;
    
    // calculate scaleFactor to resize original image to fit inside `newSize` and maintain the aspect ratio
    NSSize oldSize = self.size;
    NSRect oldRect = NSMakeRect(0.0, 0.0, oldSize.width, oldSize.height);
    CGFloat scaleFactor = portrait ?  maxSize.height / oldSize.height : maxSize.width / oldSize.width;
    NSSize newSize = NSMakeSize(oldSize.width * scaleFactor, oldSize.height * scaleFactor);
    NSRect newRect = NSMakeRect(0.0, 0.0, newSize.width, newSize.height);
    
    // composite old image into a new image
    NSImage *newImage = [[NSImage alloc] initWithSize:newSize];
    [newImage lockFocus];
    {
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [self drawInRect:newRect fromRect:oldRect operation:NSCompositeCopy fraction:1.0];
    }
    [newImage unlockFocus];
    
    return newImage;
}

- (NSImage *)scaledAndCroppedImageWithFinalSize:(NSSize)finalSize
{
    if (![self isValid])
        return nil;
    
    // cropRect = rect necessary to fit the image
    NSSize imageSize = self.size;
    NSRect initialRect = NSMakeRect(0.0, 0.0, imageSize.width, imageSize.height);
    NSRect targetRect  = NSMakeRect(0.0, 0.0, finalSize.width, finalSize.height);
    NSRect cropRect = MPCroppingRectProportionalToRect(initialRect, targetRect);
    
    // composite old image into a new image
    NSImage *newImage = [[NSImage alloc] initWithSize:finalSize];
    [newImage lockFocus];
    {
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [self drawInRect:targetRect fromRect:cropRect operation:NSCompositeCopy fraction:1.0];
    }
    [newImage unlockFocus];
    
    return newImage;
}

NSRect MPCroppingRectProportionalToRect(NSRect initialRect, NSRect targetRect)
{
    CGFloat scaleFactor1 = targetRect.size.width  / initialRect.size.width;
    CGFloat scaleFactor2 = targetRect.size.height / initialRect.size.height;
    NSRect cropRect;
    if (scaleFactor1 > scaleFactor2)
    {
        // the correct scale factor is scaleFactor1
        // target height after scaling = targetRect.size.height
        // --> used height in the initial rect = targetRect.size.height / scaleFactor1 = intialRect.size.height * scaleFactor2 / scaleFactor1;
        // --> deltaHeight = how much height to crop at the current image size
        CGFloat cropHeight  = targetRect.size.height / scaleFactor1;
        CGFloat deltaHeight = initialRect.size.height - cropHeight;
        cropRect = NSMakeRect(0.0, deltaHeight / 2.0, initialRect.size.width, cropHeight);
    }
    else
    {
        // same as above, but applied to width instead of height
        CGFloat cropWidth  = targetRect.size.width / scaleFactor2;
        CGFloat deltaWidth = initialRect.size.width - cropWidth;
        cropRect = NSMakeRect(deltaWidth / 2.0, 0.0, cropWidth, initialRect.size.height);
    }
    
    return cropRect;
}

@end
