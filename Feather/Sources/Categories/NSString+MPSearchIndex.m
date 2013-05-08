//
//  MPSearchIndex.m
//  Feather
//
//  Created by Matias Piipari on 07/05/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "NSString+MPSearchIndex.h"

@implementation NSString (MPSearchIndex)

- (NSString*)fullTextNormalizedString
{
    NSMutableString *result = [NSMutableString stringWithString:self];
    CFStringNormalize((__bridge CFMutableStringRef)result, kCFStringNormalizationFormD);
    CFStringFold((__bridge CFMutableStringRef)result,
                 kCFCompareCaseInsensitive
                 | kCFCompareDiacriticInsensitive
                 | kCFCompareWidthInsensitive, NULL);
    
    return result;
}

@end
