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
#define MPStringF(format, ...) ([NSString stringWithFormat:format, __VA_ARGS__])

#define MPFullRange(s) NSMakeRange(0, s.length)
#define MPLastIndexOfRange(r) (r.location + r.length - 1)
#define MPRangeContainsRange(r, r2) ((r.location <= r2.location) && ((r.location + r.length) <= (r2.location + r2.length)))


extern inline NSString *MPNilToEmptyString(NSString *s);
extern inline NSString *MPNilOrEmptyStringToString(NSString *s, NSString *s2);
extern inline NSString *MPNilToString(NSString *s, NSString *s2);
extern inline NSMutableString *MPMutableStringForString(NSString *s);


@interface NSString (Feather)

- (BOOL) containsSubstring:(NSString *)substring;
- (NSString *)stringByTranslatingPresentToPastTense;

- (NSString *)stringByMakingSentenceCase;

@property (readonly, copy) NSString *pluralizedString;
@property (readonly, copy) NSString *camelCasedString;

/**
 * Escapes characters that aren't either alphanumeric Unicode or in the traditional ASCII printable character range 32..127.
 */
- (NSString *) stringByEscapingNonPrintableAndInvisibleCharacters;

@end
