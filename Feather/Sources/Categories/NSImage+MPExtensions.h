//
//  NSImage+MPExtensions.h
//  Feather
//
//  Created by Matias Piipari on 13/04/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString *_Nonnull const MPImageExtensionsErrorDomain;

extern NSString *_Nonnull const MPPasteboardTypeEPS;

typedef NS_ENUM(NSUInteger, MPImageExtensionsErrorCode) {
    MPImageExtensionsErrorCodeUnknown = 0,
    MPImageExtensionsErrorCodeFailedToCreateRepresentation = 1
};

static const NSUInteger MPEMUsPerInch = 914400;


// EMU size is WordML terminology.
typedef struct MPEMUSize
{
    NSUInteger width;
    NSUInteger height;
} MPEMUSize;

@interface NSImage (MPExtensions)

- (nonnull NSImage *)roundCornersImageCornerRadius:(NSInteger)radius;

@property (readonly, nonnull) CGImageRef CGImage;

+ (nullable NSImage *)imageForURL:(nonnull NSURL *)imageURL;
- (NSUInteger)DPI;
- (MPEMUSize)EMUSize;

@property (readonly, nonnull) NSData *PNGRepresentation;

/** Return the detected bitmap image type for given data as a NSBitmapImageFileType value, 
  * or **NSNotFound** if none applies. */
+ (NSUInteger)bitmapImageTypeForData:(nonnull NSData *)data;

/** Return the detected bitmap image type for pasteboard type as a NSBitmapImageFileType value,
  * or **NSNotFound** if none applies. */
+ (NSUInteger)bitmapImageFileTypeForPasteboardType:(nonnull NSString *)pasteboardType;

+ (NSUInteger)bitmapImageFileTypeForPathExtension:(nonnull NSString *)fileExtension;

+ (nonnull NSString *)canonicalPathExtensionForBitmapImageFileType:(NSBitmapImageFileType)fileType;

/** An array of UTTs for image data formats used on the pasteboard. */
+ (nonnull NSArray<NSString *> *)prioritizedImageDataPasteboardTypes;

/** Returns an NSImage object read from the given pasteboard, and passes by reference the type of the image.
  * Image type is selected in priority, preferring PDF first, then bitmap only formats (PNG, JPEG, TIFF, BMP, JPEG2000). */
+ (nullable NSImage *)imageFromPasteboard:(nonnull NSPasteboard *)pasteboard pasteboardType:(NSString *_Nullable * _Nullable)type;

/** A framed version of the image */
- (nonnull NSImage *)framedWithSize:(NSSize)size;

/** Create an image with the size of the input image rep, with it as its only representation. */
- (nonnull NSImage *)initWithImageRep:(nonnull NSImageRep *)rep;

/** Copy a representation of the image as data with data writing and bitmap type options. */
- (nullable NSData *)imageDataWithOptions:(NSDataWritingOptions)options
                                     type:(NSBitmapImageFileType)type
                                    error:(NSError *_Nonnull *_Nonnull)error;

/** Write the image to file at the given path in a format of your choice. */
- (BOOL)writeToFile:(nonnull NSString *)path
            options:(NSDataWritingOptions)options
               type:(NSBitmapImageFileType)type
              error:(NSError *_Nullable *_Nullable)error;

+ (nullable NSImage *)resizedImage:(nonnull NSImage *)sourceImage toPixelDimensions:(NSSize)newSize;

- (nonnull NSImage *)scaledImageWithMaxSize:(NSSize)maxSize;

#pragma mark - Previews & thumbnails

+ (nonnull NSImage *)imageWithPreviewOfFileAtURL:(nonnull NSURL *)fileURL croppedAndScaledToFinalSize:(NSSize)finalSize;

+ (nonnull NSImage *)imageWithPreviewOfFileAtURL:(nonnull NSURL *)fileURL maxSize:(NSSize)maxSize;

@end

// Kindly contributed by Charles Parnot (FDFoundation)
@interface NSImage (FDImageDiff)

- (BOOL)isPixelEqualToImage:(nonnull NSImage *)image;

- (CGFloat)pixelDifferenceWithImage:(nonnull NSImage *)image;

@end
