//
//  MPObjCTranslator.m
//  Bindings
//
//  Created by Matias Piipari on 11/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import "MPObjectiveCTranslator.h"

#import <Feather/NSObject+MPExtensions.h>

@implementation MPObjCTranslator

+ (NSString *)name {
    NSAssert(false, @"Abstract method");
    return nil;
}

+ (instancetype)newTranslatorWithName:(NSString *)name {
    for (Class cls in MPObjCTranslator.subclasses) {
        if ([[cls name] isEqualToString:name]) {
            return [cls new];
        }
    }
    
    return nil;
}

- (NSString *)translationForUnit:(MPObjCTranslationUnit *)translationUnit {
    NSAssert(false, @"Abstract method");
    return nil;
}

- (NSString *)translatedPrefixedIdentifierString:(NSString *)str {
    return str.copy; // pass the string through.
}

- (NSString *)translatedEnumDeclaration:(MPObjCEnumDeclaration *)declaration {
    NSAssert(false, @"Abstract method");
    return nil;
}

- (NSString *)translatedEnumDeclarationsForTranslationUnit:(MPObjCTranslationUnit *)translationUnit {
    NSAssert(false, @"Abstract method");
    return nil;
}

@end