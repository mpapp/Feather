//
//  NSString+MPExtensions.h
//  Feather
//
//  Created by Markus Piipari on 1/18/13.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>


#define MPCharacterAtIndex(s, i) (CFStringGetCharacterAtIndex((CFStringRef)s, i))
#define MPLastIndexOfString(s) (((s != nil) && (s.length > 0)) ? (s.length - 1) : NSNotFound)
#define MPStringWithFormat(format, ...) ([NSString stringWithFormat:format, __VA_ARGS__])
#define MPStringF(format, ...) ([NSString stringWithFormat:format, __VA_ARGS__]) // Deprecated

#define MPFullRange(s) NSMakeRange(0, s.length)
#define MPLastIndexOfRange(r) (r.location + r.length - 1)
#define MPRangeContainsRange(r, r2) ((r.location <= r2.location) && ((r.location + r.length) <= (r2.location + r2.length)))


NS_INLINE NSString * _Nonnull MPNilToEmptyString(NSString * _Nullable s) {
    return (s != nil) ? s : @"";
}

NS_INLINE  NSString * _Nullable MPNilOrEmptyStringToString(NSString *_Nullable s, NSString *_Nullable s2)
{
    return ((s.length > 0) ? s : s2);
}

NS_INLINE  NSString * _Nonnull MPNilToString(NSString *_Nullable  s, NSString *_Nullable s2)
{
    return (s != nil) ? s : MPNilToEmptyString(s2);
}

NS_INLINE  NSMutableString *_Nonnull MPMutableStringForString(NSString *_Nonnull s)
{
    if ([s isKindOfClass:NSMutableString.class]) {
        return (NSMutableString *)s;
    }
    return [NSMutableString stringWithString:s];
}


@interface NSString (Feather)

- (BOOL)containsSubstring:(nonnull NSString *)substring;

- (nullable NSString *)substringUpToEndOfFirstOccurrenceOfString:(nonnull NSString *)s;

- (nonnull NSString *)stringByTranslatingPresentToPastTense;

- (nonnull NSString *)stringByMakingSentenceCase;

@property (readonly, copy, nonnull) NSString *pluralizedString;
@property (readonly, copy, nonnull) NSString *camelCasedString;

@property (readonly, copy, nonnull) NSString *stringByRemovingWhitespace;

@property (readonly, copy, nonnull) NSString *sentenceCasedString;

@property (readonly) BOOL isAllUpperCase;

/** Escapes characters that aren't either alphanumeric Unicode or in the traditional ASCII printable character range 32..127. */
@property (copy, readonly, nonnull) NSString *stringByEscapingNonPrintableAndInvisibleCharacters;

/** Unescape XML entities in the input. */
@property (copy, readonly, nonnull) NSString *stringByUnescapingXMLEntities;

/** Escape XML entities in the input. */
@property (copy, readonly, nonnull) NSString *stringByEscapingXMLEntities;

/** Removes instances of characters in the whitespace character set from the string. */
@property (copy, readonly, nonnull) NSString *stringByTrimmingLeadingWhitespace;

@property (copy, readonly, nonnull) NSString *stringByTrimmingTrailingWhitespace;

@property (copy, readonly, nonnull) NSString *HTMLStringCleanedFromWebKitArtefacts;

@property (copy, readonly, nonnull) NSString *stringByRemovingHTMLTags;

@property (copy, readonly, nonnull) NSString *slugString;

/** A best effort to return the top level domain part of a host name. 
  * For instance returns 'twitter.com' for 'dev.twitter.com'. */
+ (nullable NSString *)rootDomainForHostName:(nonnull NSString *)hostName;

- (nonnull NSString *)stringByTrimmingToLength:(NSUInteger)len truncate:(BOOL)truncate;

/** String representation of an OSType. Works also for FourLetterCode, DescType, ResType */
+ (nonnull NSString *)stringWithOSType:(OSType)type;

/** Validates the string as an email address. Note that the presentation email does not exhaustively follow all the RFCs but is a best effort.
  * See http://blog.logichigh.com/2010/09/02/validating-an-e-mail-address/ and http://stackoverflow.com/questions/3139619/check-that-an-email-address-is-valid-on-ios for more info. */
@property (readonly) BOOL isValidEmailAddress;

/** OSType (FourLetterCode, DescType, ResType) representation of a string. */
@property (readonly) OSType OSType;

typedef void (^MPCharacterEvaluationBlock)(const unichar currentChar, NSUInteger i);
-(void)enumerateCharacters:(_Nonnull MPCharacterEvaluationBlock)enumerationBlock;

@end

@interface NSMutableString (Feather)
- (void)removeCharactersInSet:(nonnull NSCharacterSet *)set;
@end
