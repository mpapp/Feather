//
//  NSAttributedString+MPExtensions.m
//  Feather
//
//  Created by Matias Piipari on 12/04/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import "NSAttributedString+MPExtensions.h"

#import "NSImage+MPExtensions.h"

int gNSStringGeometricsTypesetterBehavior = NSTypesetterLatestBehavior;

@implementation NSAttributedString (MPExtensions)

#pragma mark * Measure Attributed String

- (NSSize)sizeForWidth:(float)width
				height:(float)height {
	NSSize answer = NSZeroSize ;
    if ([self length] > 0) {
		// Checking for empty string is necessary since Layout Manager will give the nominal
		// height of one line if length is 0.  Our API specifies 0.0 for an empty string.
		NSSize size = NSMakeSize(width, height) ;
		NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:size] ;
		NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:self] ;
		NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init] ;
		[layoutManager addTextContainer:textContainer] ;
		[textStorage addLayoutManager:layoutManager] ;
		[layoutManager setHyphenationFactor:0.0] ;
		if (gNSStringGeometricsTypesetterBehavior != NSTypesetterLatestBehavior) {
			[layoutManager setTypesetterBehavior:gNSStringGeometricsTypesetterBehavior] ;
		}
		// NSLayoutManager is lazy, so we need the following kludge to force layout:
		[layoutManager glyphRangeForTextContainer:textContainer] ;
        
		answer = [layoutManager usedRectForTextContainer:textContainer].size ;
        
		// In case we changed it above, set typesetterBehavior back
		// to the default value.
		gNSStringGeometricsTypesetterBehavior = NSTypesetterLatestBehavior ;
	}
    
	return answer ;
}

- (float)heightForWidth:(float)width {
	return [self sizeForWidth:width
					   height:FLT_MAX].height ;
}

- (float)widthForHeight:(float)height {
	return [self sizeForWidth:FLT_MAX
					   height:height].width ;
}

@end


@implementation NSString (MPExtensions)

#pragma mark * Given String with Attributes

- (NSSize)sizeForWidth:(float)width
				height:(float)height
			attributes:(NSDictionary*)attributes {
	NSSize answer ;
    
	NSAttributedString *astr = [[NSAttributedString alloc] initWithString:self
															   attributes:attributes] ;
	answer = [astr sizeForWidth:width
						 height:height] ;
	return answer ;
}

- (float)heightForWidth:(float)width
			 attributes:(NSDictionary*)attributes {
	return [self sizeForWidth:width
					   height:FLT_MAX
				   attributes:attributes].height ;
}

- (float)widthForHeight:(float)height
			 attributes:(NSDictionary*)attributes {
	return [self sizeForWidth:FLT_MAX
					   height:height
				   attributes:attributes].width ;
}

#pragma mark * Given String with Font

- (NSSize)sizeForWidth:(float)width
				height:(float)height
				  font:(NSFont*)font {
	NSSize answer = NSZeroSize ;
    
	if (font == nil) {
		NSLog(@"[%@ %@]: Error: cannot compute size with nil font", [self class], NSStringFromSelector(_cmd)) ;
	}
	else {
		NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:
									font, NSFontAttributeName, nil] ;
		answer = [self sizeForWidth:width
							 height:height
						 attributes:attributes] ;
	}
    
	return answer ;
}

- (float)heightForWidth:(float)width
				   font:(NSFont*)font {
	return [self sizeForWidth:width
					   height:FLT_MAX
						 font:font].height ;
}

- (float)widthForHeight:(float)height
				   font:(NSFont*)font {
	return [self sizeForWidth:FLT_MAX
					   height:height
						 font:font].width ;
}

@end



/* From http://stackoverflow.com/questions/23370275/trouble-saving-nsattributedstring-with-image-to-an-rtf-file/23607696 */
@implementation NSAttributedString (MMRTFWithImages)

- (NSString *)encodeRTFWithImages {
    
    NSMutableAttributedString *stringToEncode = [[NSMutableAttributedString alloc] initWithAttributedString:self];
    NSRange strRange = NSMakeRange(0, stringToEncode.length);
    
    //
    // Prepare the attributed string by removing the text attachments (images) and replacing them by
    // references to the images dictionary
    NSMutableDictionary *attachmentDictionary = [NSMutableDictionary dictionary];
    while (strRange.length > 0 && (strRange.location + strRange.length) <= stringToEncode.length) {
        // Get the next text attachment
        NSRange effectiveRange;
        
        NSTextAttachment *textAttachment = nil;
        
        @try {
            textAttachment = [stringToEncode attribute:NSAttachmentAttributeName
                                               atIndex:strRange.location
                                        effectiveRange:&effectiveRange];
        }
        @catch (id e) {
            NSLog(@"ERROR: %@", e);
        }
        
        strRange = NSMakeRange(NSMaxRange(effectiveRange), NSMaxRange(strRange) - NSMaxRange(effectiveRange));
        
        if (textAttachment) {
            // Text attachment found -> store image to image dictionary and remove the attachment
            NSFileWrapper *fileWrapper = [textAttachment fileWrapper];
            
            NSImage *image = [[NSImage alloc] initWithData:[fileWrapper regularFileContents]];
            
            // Keep image size
            //NSImage *scaledImage = [self imageFromImage:image
            //                                   withSize:textAttachment.bounds.size];
            NSString *imageKey = [NSString stringWithFormat:@"_MM_Encoded_Image#%zi_", [image hash]];
            attachmentDictionary[imageKey] = image;
            
            [stringToEncode removeAttribute:NSAttachmentAttributeName range:effectiveRange];
            [stringToEncode replaceCharactersInRange:effectiveRange withString:imageKey];
            strRange.length += [imageKey length] - 1;
        } // if
    } // while
    
    //
    // Create the RTF stream; without images but including our references
    NSData *rtfData = [stringToEncode dataFromRange:NSMakeRange(0, stringToEncode.length)
                                 documentAttributes:@{
                                                      NSDocumentTypeDocumentAttribute:NSRTFTextDocumentType
                                                      }
                                              error:NULL];
    NSMutableString *rtfString = [[NSMutableString alloc] initWithData:rtfData
                                                              encoding:NSASCIIStringEncoding];
    
    //
    // Replace the image references with hex encoded image data
    for (id key in attachmentDictionary) {
        NSRange keyRange = [rtfString rangeOfString:(NSString*)key];
        if (NSNotFound != keyRange.location) {
            // Reference found -> replace with hex coded image data
            NSImage *image = [attachmentDictionary objectForKey:key];
            NSData *pngData = [image PNGRepresentation];
            
            NSString *hexCodedString = [self hexadecimalRepresentation:pngData];
            NSString *encodedImage = [NSString stringWithFormat:@"{\\*\\shppict {\\pict \\pngblip %@}}", hexCodedString];
            
            [rtfString replaceCharactersInRange:keyRange withString:encodedImage];
        }
    }
    
    return rtfString;
}

/* From http://stackoverflow.com/questions/23370275/trouble-saving-nsattributedstring-with-image-to-an-rtf-file */
- (NSString *)hexadecimalRepresentation:(NSData *)pData {
    
    static const char*  hexDigits = "0123456789ABCDEF";
    
    NSString *result = nil;
    
    size_t length = pData.length;
    if (length) {
        NSMutableData*  tempData = [NSMutableData dataWithLength:(length << 1)];    // double length
        if (tempData) {
            const unsigned char*    src = [pData bytes];
            unsigned char*          dst = [tempData mutableBytes];
            
            if ((src) &&
                (dst)) {
                // encode nibbles
                while (length--) {
                    *dst++ = hexDigits[(*src >> 4) & 0x0F];
                    *dst++ = hexDigits[(*src++ & 0x0F)];
                } // while
                
                result = [[NSString alloc] initWithData:tempData
                                               encoding:NSASCIIStringEncoding];
            } // if
        } // if
    } // if
    return result;
}

@end

@implementation NSAttributedString (Manuscripts)

+ (NSAttributedString *)attributedStringFromString:(NSString *)s
                                        attributes:(NSDictionary *)attributes
{
    return [[NSAttributedString alloc] initWithString:s attributes:attributes];
}

@end


@implementation NSMutableAttributedString (Manuscripts)

- (void) appendString:(NSString *)s
{
    [self replaceCharactersInRange:NSMakeRange(self.length, 0) withString:s];
}

- (void) insertString:(NSString *)s atIndex:(NSUInteger)location
{
    [self replaceCharactersInRange:NSMakeRange(location, 0) withString:s];
}

@end


@implementation NSDictionary (ManuscriptsAttributedString)

+ (NSDictionary *)textAttributesWithFontNamed:(NSString *)fontName fontSize:(CGFloat)fontSize bold:(BOOL)bold italic:(BOOL)italic color:(NSColor *)color
{
    NSFont *font = [NSFont fontWithName:fontName size:fontSize];
    
    NSFontTraitMask traits = 0;
    if (bold) traits = (traits | NSBoldFontMask);
    if (italic) traits = (traits | NSItalicFontMask);
    
    font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:traits];
    
    return @{
             NSFontAttributeName: font,
             NSForegroundColorAttributeName: color
             };
}

+ (NSDictionary *)textAttributesWithSystemFontOfSize:(CGFloat)fontSize bold:(BOOL)bold
{
    NSFont *font = [NSFont systemFontOfSize:fontSize];
    
    if (bold)
    {
        font = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSBoldFontMask];
    }
    
    return @{NSFontAttributeName: font};
}

@end


@implementation NSAttributedString (Hyperlink)
+(id)hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL
{
    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString: inString];
    NSRange range = NSMakeRange(0, [attrString length]);
    
    [attrString beginEditing];
    [attrString addAttribute:NSLinkAttributeName value:[aURL absoluteString] range:range];
    
    // make the text appear in blue
    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
    
    // next make the text appear with an underline
    [attrString addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
    
    [attrString endEditing];
    
    return attrString;
}
@end
