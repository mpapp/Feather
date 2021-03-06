//
//  MPObjCTranslator.h
//  Bindings
//
//  Created by Matias Piipari on 11/10/2014.
//  Copyright (c) 2014-2015 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MPObjectiveCTokens.h"

@interface MPObjCTranslator : NSObject

+ (NSString *)name;
+ (MPObjCTranslator *)newTranslatorWithName:(NSString *)name;

@property (readwrite) NSString *identifierPrefix;

- (NSString *)translationForUnit:(MPObjCTranslationUnit *)translationUnit;

- (NSString *)translatedPrefixedIdentifierString:(NSString *)str;

- (NSString *)translatedEnumDeclarationsForTranslationUnit:(MPObjCTranslationUnit *)translationUnit;

- (NSString *)translatedEnumDeclaration:(MPObjCEnumDeclaration *)declaration;

- (NSString *)translatedConstantDeclarationsForTranslationUnit:(MPObjCTranslationUnit *)tUnit
                                                   libraryName:(NSString *)libraryName;


- (NSString *)translatedProtocolDeclarationsForTranslationUnit:(MPObjCTranslationUnit *)tUnit;

- (NSString *)translatedProtocolDeclaration:(MPObjCProtocolDeclaration *)propDec;

- (NSString *)translatedClassDeclarationsForTranslationUnit:(MPObjCTranslationUnit *)tUnit;

@end