//
//  MPObjectiveCTranslator.m
//  Bindings
//
//  Created by Matias Piipari on 11/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import "MPObjectiveCTranslator.h"

#import <Feather/NSObject+MPExtensions.h>

@implementation MPObjectiveCTranslator

+ (NSString *)name {
    NSAssert(false, @"Abstract method");
    return nil;
}

+ (instancetype)newTranslatorWithName:(NSString *)name {
    for (Class cls in [NSObject subclassesForClass:MPObjectiveCTranslator.class]) {
        if ([[cls name] isEqualToString:name]) {
            return [cls new];
        }
    }
    
    return nil;
}

- (NSString *)translationForUnit:(MPObjectiveCTranslationUnit *)translationUnit {
    NSAssert(false, @"Abstract method");
    return nil;
}

- (NSString *)translatedPrefixedIdentifierString:(NSString *)str {
    return str.copy; // pass the string through.
}

- (NSString *)translatedEnumDeclaration:(MPObjectiveCEnumDeclaration *)declaration {
    NSAssert(false, @"Abstract method");
    return nil;
}

- (NSString *)translatedEnumDeclarationsForTranslationUnit:(MPObjectiveCTranslationUnit *)translationUnit {
    NSAssert(false, @"Abstract method");
    return nil;
}

@end