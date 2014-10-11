//
//  MPObjectiveCTranslator.h
//  Bindings
//
//  Created by Matias Piipari on 11/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MPObjectiveCTokens.h"
#import "MPObjectiveCTokens.h"

@interface MPObjectiveCTranslator : NSObject

+ (NSString *)name;
+ (MPObjectiveCTranslator *)newTranslatorWithName:(NSString *)name;

@property (readwrite) NSString *identifierPrefix;

- (NSString *)translationForUnit:(MPObjectiveCTranslationUnit *)translationUnit;

- (NSString *)translatedPrefixedIdentifierString:(NSString *)str;

- (NSString *)translatedEnumDeclarationsForTranslationUnit:(MPObjectiveCTranslationUnit *)translationUnit;

- (NSString *)translatedEnumDeclaration:(MPObjectiveCEnumDeclaration *)declaration;

@end