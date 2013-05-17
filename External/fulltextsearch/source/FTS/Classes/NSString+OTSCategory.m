#import "NSString+OTSCategory.h"

@implementation NSString (OTSCategory)

- (NSString*)otsNormalizeString
{
  if (!self) return nil;
  
  NSMutableString *result = [NSMutableString stringWithString:self];
  CFStringNormalize((__bridge CFMutableStringRef)result, kCFStringNormalizationFormD);
  CFStringFold((__bridge CFMutableStringRef)result, kCFCompareCaseInsensitive | kCFCompareDiacriticInsensitive | kCFCompareWidthInsensitive, NULL);
  
  return result;
}

@end
