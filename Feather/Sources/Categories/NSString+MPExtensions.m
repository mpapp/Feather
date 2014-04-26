//
//  NSString+Feather.m
//  Feather
//
//  Created by Markus Piipari on 1/18/13.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//


#import "NSString+MPExtensions.h"

#import "RegexKitLite.h"


@implementation NSString (Feather)

- (BOOL)hasContent { return self.length > 0; }

- (NSString *)stringByMakingSentenceCase
{
    NSMutableString *str = [[NSMutableString alloc] initWithString:self];
    [str replaceOccurrencesOfRegex:@"^(.)"
                        usingBlock:
     ^NSString *(NSInteger captureCount,
                 NSString *const __unsafe_unretained *capturedStrings,
                 const NSRange *capturedRanges,
                 volatile BOOL *const stop) {
         assert(captureCount == 2);
         return [capturedStrings[0] uppercaseString];
    }];
    return [str copy];
}

- (BOOL) containsSubstring:(NSString *)substring
{
    return ([self rangeOfString:substring].location != NSNotFound);
}

- (NSString *)stringByTranslatingPresentToPastTense
{
    return [[self stringByReplacingOccurrencesOfRegex:@"e$" withString:@""] stringByAppendingString:@"ed"];
}

- (NSString *)pluralizedString
{
    if ([self isMatchedByRegex:@"y$"])
    {
        return [self stringByReplacingOccurrencesOfRegex:@"y$" withString:@"ies"];
    }
    return [self stringByAppendingString:@"s"];
}

- (NSString *)camelCasedString
{
    NSMutableString *str = [NSMutableString stringWithString:self];
    [str replaceOccurrencesOfRegex:@"^(.)"
                        usingBlock:^NSString *(NSInteger captureCount,
                                               NSString *const __unsafe_unretained *capturedStrings,
                                               const NSRange *capturedRanges,
                                               volatile BOOL *const stop)
    {
        assert(captureCount > 0);
        return [capturedStrings[0] lowercaseString];
    }];
    return [str copy];
}

/*
 Lifted from: http://blog.hozbox.com/2012/01/03/escaping-all-control-characters-in-a-nsstring/
 */
- (NSString *) repr {
    NSMutableString *myRepr = [[NSMutableString alloc] initWithString:self];
    NSRange myRange = NSMakeRange(0, [self length]);
    NSArray *toReplace = @[@"\0", @"\a", @"\b", @"\t", @"\n", @"\f", @"\r", @"\e"];
    NSArray *replaceWith = @[@"\\0", @"\\a", @"\\b", @"\\t", @"\\n", @"\\f", @"\\r", @"\\e"];
    for (NSUInteger i = 0, count = [toReplace count]; i < count; ++i) {
        [myRepr replaceOccurrencesOfString:toReplace[i] withString:replaceWith[i] options:0 range:myRange];
    }
    NSString *retStr = [NSString stringWithFormat:@"\"%@\"", myRepr];
    //[myRepr release];
    return retStr;
}

- (NSString *) stringByEscapingNonPrintableAndInvisibleCharacters
{
    NSMutableString *result = [[NSMutableString alloc] init];
    NSString *s = [self repr];
    
    for (NSInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        
        if ((c >= ' ' && c < 126) || [NSCharacterSet.alphanumericCharacterSet characterIsMember:c]) {
            [result appendFormat:@"%c", c];
        } else {
            [result appendFormat:@"\\x%lx", (unsigned long)c];
        }
    }
    
    return result;
}

@end