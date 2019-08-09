//
//  NSString+Feather.m
//  Feather
//
//  Created by Markus Piipari on 1/18/13.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//


#import "NSString+MPExtensions.h"

@import CoreServices;

@interface NSStringHTMLStripParser : NSObject<NSXMLParserDelegate> {
@private
    NSMutableArray* strings;
}
- (NSString*)getCharsFound;
@end

@implementation NSStringHTMLStripParser

- (id)init {
    if ((self = [super init])) {
        strings = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)parser:(NSXMLParser*)parser foundCharacters:(NSString*)string {
    [strings addObject:string];
}

- (NSString *)getCharsFound {
    return [strings componentsJoinedByString:@""];
}

@end

@implementation NSString (Feather)

- (NSString *)substringAfter:(NSString *)s
{
    NSRange r = [self rangeOfString:s];
    if (r.location == NSNotFound)
        return nil;
    NSString *substring = [self substringFromIndex:(r.location + r.length)];
    return substring;
}

- (NSString *)substringBefore:(NSString *)s
{
    NSRange r = [self rangeOfString:s];
    if (r.location == NSNotFound)
        return nil;
    NSString *substring = [self substringToIndex:r.location];
    return substring;
}

- (NSString *)stringByTrimmingWhitespace
{
    static NSCharacterSet *characters = nil;
    if (!characters)
        characters = [NSCharacterSet whitespaceCharacterSet];
    return [self stringByTrimmingCharactersInSet:characters];
}

- (NSString *)stringByTrimmingWhitespaceAndNewlines
{
    static NSCharacterSet *characters = nil;
    if (!characters)
        characters = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    return [self stringByTrimmingCharactersInSet:characters];
}

- (NSString *)stringByNormalizingWhitespace
{
    return [self stringByNormalizingWhitespaceAllowLeading:NO trailingWhitespace:NO];
}

- (NSString *)stringByNormalizingWhitespaceAllowLeading:(BOOL)allowLeadingWhitespace
                                     trailingWhitespace:(BOOL)allowTrailingWhitespace
{
    if (self.length < 1) {
        return self;
    }
    
    NSString *s = [self stringByTrimmingWhitespaceAndNewlines];
    NSArray *components = [s componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    components = [components filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  object, NSDictionary<NSString *,id> * _Nullable bindings) {
        return ![object isEqualToString:@""];
    }]];
    
    NSString *normalized = [components componentsJoinedByString:@" "];
    
    BOOL restoreLeadingWhitespace = allowLeadingWhitespace && [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[self characterAtIndex:0]];
    BOOL restoreTrailingWhitespace = allowTrailingWhitespace && [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[self characterAtIndex:(self.length - 1)]];
    
    if (restoreLeadingWhitespace && restoreTrailingWhitespace) {
        normalized = [NSString stringWithFormat: @" %@ ", normalized];
    }
    else if (restoreLeadingWhitespace) {
        normalized = [NSString stringWithFormat: @" %@", normalized];
    }
    else if (restoreTrailingWhitespace) {
        normalized = [NSString stringWithFormat: @"%@ ", normalized];
    }
    
    return normalized;
}

- (BOOL)hasContent { return self.length > 0; }

- (BOOL)containsSubstring:(NSString *)substring
{
    return ([self rangeOfString:substring].location != NSNotFound);
}

- (NSString *)substringUpToEndOfFirstOccurrenceOfString:(NSString *)s
{
    NSRange r = [self rangeOfString:s];
    if (r.location == NSNotFound)
        return nil;
    NSString *substring = [self substringToIndex:(r.location + r.length)];
    return substring;
}

// lifted from http://stackoverflow.com/questions/2432452/how-to-capitalize-the-first-word-of-the-sentence-in-objective-c
- (NSString *)sentenceCasedString {
    if (self.length == 0)
        return @"";
    
    return [self stringByReplacingCharactersInRange:NSMakeRange(0,1)
                                         withString:[self substringToIndex:1].capitalizedString];;
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

- (NSString *)stringByEscapingXMLEntities
{
    CFStringRef str = CFXMLCreateStringByEscapingEntities(kCFAllocatorDefault, (__bridge CFStringRef)self, NULL);
    return (__bridge_transfer NSString *)str;
}

- (NSString *)stringByUnescapingXMLEntities
{
    CFStringRef str
        = CFXMLCreateStringByUnescapingEntities(
            kCFAllocatorDefault,
            (__bridge CFStringRef)self,
            NULL);
    
    return (__bridge_transfer NSString *)str;
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

// http://stackoverflow.com/questions/5689288/how-to-remove-whitespace-from-right-end-of-nsstring
- (NSString *)stringByTrimmingTrailingCharactersInSet:(NSCharacterSet *)characterSet {
    NSUInteger location = 0;
    NSUInteger length = [self length];
    unichar charBuffer[length];
    [self getCharacters:charBuffer];
    
    for (; length > 0; length--) {
        if (![characterSet characterIsMember:charBuffer[length - 1]]) {
            break;
        }
    }
    
    return [self substringWithRange:NSMakeRange(location, length - location)];
}

- (NSString *)stringByTrimmingTrailingWhitespace
{
    return [self stringByTrimmingTrailingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)HTMLStringCleanedFromWebKitArtefacts {
    return [[self stringByReplacingOccurrencesOfString:@"&nbsp;" withString:@" "] stringByReplacingOccurrencesOfString:@"<br>" withString:@""];
}

- (NSString *)stringByRemovingHTMLTags {
    // take this string obj and wrap it in a root element to ensure only a single root element exists
    // and that any ampersands are escaped to preserve the escaped sequences
    NSString* string = [self stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    string = [NSString stringWithFormat:@"<root>%@</root>", string];
    
    // add the string to the xml parser
    NSStringEncoding encoding = string.fastestEncoding;
    NSData* data = [string dataUsingEncoding:encoding];
    NSXMLParser* parser = [[NSXMLParser alloc] initWithData:data];
    
    // parse the content keeping track of any chars found outside tags (this will be the stripped content)
    NSStringHTMLStripParser *parsee = [[NSStringHTMLStripParser alloc] init];
    parser.delegate = parsee;
    [parser parse];
    
    // log any errors encountered while parsing
    NSError * error = nil;
    if((error = [parser parserError])) {
        NSLog(@"WARN: %@", error);
    }
    
    // any chars found while parsing are the stripped content
    NSString *strippedString = [parsee getCharsFound];
    strippedString = [strippedString stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
    
    // get the raw text out of the parsee after parsing, and return it
    
    strippedString = [strippedString stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
    strippedString = [strippedString stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
    
    return strippedString;
}

// from https://gist.github.com/RobertAudi/5926772
- (NSString *)slugString {
    NSString        *separator        = @"-";
    NSMutableString *slugalizedString = [NSMutableString string];
    NSRange         replaceRange      = NSMakeRange(0, self.length);
    
    // Remove all non ASCII characters
    NSError *nonASCIICharsRegexError = nil;
    NSRegularExpression *nonASCIICharsRegex = [NSRegularExpression regularExpressionWithPattern:@"[^\\x00-\\x7F]+"
                                                                                        options:0
                                                                                          error:&nonASCIICharsRegexError];
    slugalizedString = [[nonASCIICharsRegex stringByReplacingMatchesInString:self
                                                                     options:0
                                                                       range:replaceRange
                                                                withTemplate:@""] mutableCopy];
    
    // Turn non-slug characters into separators
    NSError *nonSlugCharactersError = nil;
    NSRegularExpression *nonSlugCharactersRegex = [NSRegularExpression regularExpressionWithPattern:@"[^a-z0-9\\-_\\+]+"
                                                                                            options:NSRegularExpressionCaseInsensitive
                                                                                              error:&nonSlugCharactersError];
    slugalizedString = [[nonSlugCharactersRegex stringByReplacingMatchesInString:slugalizedString
                                                                         options:0
                                                                           range:replaceRange
                                                                    withTemplate:separator] mutableCopy];
    
    // No more than one of the separator in a row
    NSError *repeatingSeparatorsError = nil;
    NSRegularExpression *repeatingSeparatorsRegex = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"%@{2,}", separator]
                                                                                              options:0
                                                                                                error:&repeatingSeparatorsError];
    
    slugalizedString = [[repeatingSeparatorsRegex stringByReplacingMatchesInString:slugalizedString
                                                                           options:0
                                                                             range:replaceRange
                                                                      withTemplate:separator] mutableCopy];
    
    // Remove leading/trailing separator
    slugalizedString = [[slugalizedString stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:separator]] mutableCopy];
    
    return [slugalizedString lowercaseString];
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

- (BOOL)isAllUpperCase {
    NSRange lcr = [self rangeOfCharacterFromSet:[NSCharacterSet lowercaseLetterCharacterSet]];
    NSRange ucr = [self rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]];
    return (lcr.location == NSNotFound && ucr.location != NSNotFound);
}

// http://stackoverflow.com/questions/5034628/retrieve-root-url-nsstring
+ (NSString *)rootDomainForHostName:(NSString *)domain {
    domain = domain.lowercaseString;
    
    // Return nil if none found.
    NSString *rootDomain = nil;
    
    // Convert the string to an NSURL to take advantage of NSURL's parsing abilities.
    NSURL *url = [NSURL URLWithString:domain];
    
    // Get the host, e.g. "secure.twitter.com"
    NSString *host = [url host];
    
    // Separate the host into its constituent components, e.g. [@"secure", @"twitter", @"com"]
    NSArray *hostComponents = [host componentsSeparatedByString:@"."];
    if ([hostComponents count] >=2) {
        // Create a string out of the last two components in the host name, e.g. @"twitter" and @"com"
        rootDomain = [NSString stringWithFormat:@"%@.%@",
                      [hostComponents objectAtIndex:([hostComponents count] - 2)],
                      [hostComponents objectAtIndex:([hostComponents count] - 1)]];
    }
    
    return rootDomain;
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

+ (NSString *)stringWithOSType:(OSType)type
{
    UInt32 _type = Endian32_Swap(type);
    NSData *data = [NSData dataWithBytes:&_type length:sizeof(_type)];
    return ([[NSString alloc] initWithData:data encoding:NSMacOSRomanStringEncoding]);
}

- (OSType)OSType
{
    NSData *stringData = [self dataUsingEncoding:NSMacOSRomanStringEncoding];
    
    UInt32 type, _type;
    //[stringData getBytes:&type];
    [stringData getBytes:&type length:sizeof(UInt32)];
    
    _type = Endian32_Swap(type);
    return(_type);
}

- (BOOL)isValidEmailAddress {
    BOOL stricterFilter = NO; // Discussion http://blog.logichigh.com/2010/09/02/validating-an-e-mail-address/
    static const NSString *stricterFilterString = @"[A-Z0-9a-z\\._%+-]+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2,4}";
    static const NSString *laxString = @".+@([A-Za-z0-9-]+\\.)+[A-Za-z]{2}[A-Za-z]*";
    const NSString *emailRegex = stricterFilter ? stricterFilterString : laxString;
    
    NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
    return [emailTest evaluateWithObject:self];
}

// from https://gist.github.com/programmingthomas/6856295
-(void)enumerateCharacters:(MPCharacterEvaluationBlock)enumerationBlock
{
    const unichar * chars = CFStringGetCharactersPtr((__bridge CFStringRef)self);
    //Function will return NULL if internal storage of string doesn't allow for easy iteration
    if (chars != NULL)
    {
        NSUInteger index = 0;
        while (*chars) {
            enumerationBlock(*chars, index);
            chars++;
            index++;
        }
    }
    else
    {
        //Use IMP/SEL if the other enumeration is unavailable
        SEL sel = @selector(characterAtIndex:);
        unichar (*charAtIndex)(id, SEL, NSUInteger) = (typeof(charAtIndex)) [self methodForSelector:sel];
        
        for (NSUInteger i = 0; i < self.length; i++)
        {
            const unichar c = charAtIndex(self, sel, i);
            enumerationBlock(c, i);
        }
    }
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
