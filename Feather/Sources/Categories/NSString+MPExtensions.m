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

- (BOOL)containsSubstring:(NSString *)substring
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

- (NSString *)stringByEscapingNonPrintableAndInvisibleCharacters
{
    NSMutableString *result = [[NSMutableString alloc] init];
    NSString *s = [self repr];
    
    for (NSInteger i = 0; i < s.length; i++) {
        unichar c = [s characterAtIndex:i];
        
        if ((c >= ' ' && c < 126) || [NSCharacterSet.alphanumericCharacterSet characterIsMember:c]) {
            [result appendFormat:@"%c", c];
        } else {
            [result appendFormat:@"\\x%lx", (NSUInteger)c];
        }
    }
    
    return result;
}

// http://stackoverflow.com/questions/3200521/cocoa-trim-all-leading-whitespace-from-nsstring
- (NSString*)stringByTrimmingLeadingWhitespace
{
    NSInteger i = 0;
    
    while ((i < [self length])
           && [[NSCharacterSet whitespaceCharacterSet] characterIsMember:[self characterAtIndex:i]]) {
        i++;
    }
    return [self substringFromIndex:i];
}

// Extracted from papers-shared NSString_Extensions
- (NSString *)stringByRemovingCharactersFromSet:(NSCharacterSet *)set
{
    if ([self rangeOfCharacterFromSet:set options:NSLiteralSearch].length == 0)
        return self;
    
    NSMutableString *temp = [self mutableCopy];
    [temp removeCharactersInSet:set];
    return [temp copy];
}

// Extracted from papers-shared NSString_Extensions
- (NSString *)stringByRemovingWhitespace
{
    return [self stringByRemovingCharactersFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

// inspired by NSString_Extensions
- (NSString *)stringByTrimmingToLength:(NSUInteger)len truncate:(BOOL)truncate
{
    if (self.length <= len)
        return self.copy;
    
    NSString *str = [self substringToIndex:len];
    
    if (truncate)
        str = [[str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
               stringByAppendingString:@"..."];
    
    return str;
}

@end

// Extracted from papers-shared NSString_Extensions
@implementation NSMutableString (Feather)

- (void)removeCharactersInSet:(NSCharacterSet *)set
{
    NSRange	matchRange, searchRange, replaceRange;
    NSUInteger length = [self length];
    matchRange = [self rangeOfCharacterFromSet:set options:NSLiteralSearch range:NSMakeRange(0, length)];
    
    while(matchRange.length > 0)
    {
        replaceRange = matchRange;
        searchRange.location = NSMaxRange(replaceRange);
        searchRange.length = length - searchRange.location;
        
        for(;;){
            matchRange = [self rangeOfCharacterFromSet:set options:NSLiteralSearch range:searchRange];
            if((matchRange.length == 0) || (matchRange.location != searchRange.location))
                break;
            replaceRange.length += matchRange.length;
            searchRange.length -= matchRange.length;
            searchRange.location += matchRange.length;
        }
        
        [self deleteCharactersInRange:replaceRange];
        matchRange.location -= replaceRange.length;
        length -= replaceRange.length;
    }
}

@end