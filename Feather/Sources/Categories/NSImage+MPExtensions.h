//
//  NSImage+MPExtensions.h
//  Feather
//
//  Created by Matias Piipari on 13/04/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString *const MPImageExtensionsErrorDomain;

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

- (NSImage *)roundCornersImageCornerRadius:(NSInteger)radius;

@property (readonly) CGImageRef CGImage;

+ (NSImage *)imageForURL:(NSURL *)imageURL;
- (NSUInteger)DPI;
- (MPEMUSize)EMUSize;

@property (readonly) NSData *PNGRepresentation;

/** Return the detected bitmap image type for given data as a NSBitmapImageFileType value, 
  * or **NSNotFound** if none applies. */
+ (NSUInteger)bitmapImageTypeForData:(NSData *)data __attribute__((nonnull));

/** Return the detected bitmap image type for pasteboard type as a NSBitmapImageFileType value,
  * or **NSNotFound** if none applies. */
+ (NSUInteger)bitmapImageFileTypeForPasteboardType:(NSString *)pasteboardType;

+ (NSUInteger)bitmapImageFileTypeForPathExtension:(NSString *)fileExtension;

+ (NSString *)canonicalPathExtensionForBitmapImageFileType:(NSBitmapImageFileType)fileType;

/** An array of UTTs for image data formats used on the pasteboard. */
+ (NSArray *)prioritizedImageDataPasteboardTypes;

/** Returns an NSImage object read from the given pasteboard, and passes by reference the type of the image.
  * Image type is selected in priority, preferring PDF first, then bitmap only formats (PNG, JPEG, TIFF, BMP, JPEG2000). */
+ (NSImage *)imageFromPasteboard:(NSPasteboard *)pasteboard pasteboardType:(NSString **)type;

/** A framed version of the image */
- (NSImage *)framedWithSize:(NSSize)size;

/** Copy a representation of the image as data with data writing and bitmap type options. */
- (NSData *)imageDataWithOptions:(NSDataWritingOptions)options
                            type:(NSBitmapImageFileType)type
                           error:(NSError **)error;

/** Write the image to file at the given path in a format of your choice. */
- (BOOL)writeToFile:(NSString *)path
            options:(NSDataWritingOptions)options
               type:(NSBitmapImageFileType)type
              error:(NSError **)error;

@end

// Kindly contributed by Charles Parnot (FDFoundation)
@interface NSImage (FDImageDiff)

- (BOOL)isPixelEqualToImage:(NSImage *)image;

- (CGFloat)pixelDifferenceWithImage:(NSImage *)image;

@end