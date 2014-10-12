//
//  MPObjectiveCCSharpTranslator.m
//  Bindings
//
//  Created by Matias Piipari on 11/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import "MPObjectiveCToCSharpTranslator.h"

#import <Feather/RegexKitLite.h>

#import "MPIndentedMutableString.h"

@interface MPObjectiveCToCSharpTranslator ()

@property (readwrite) NSUInteger indentationLevel;

@property (readwrite) MPIndentedMutableString *string;

@end

@implementation MPObjectiveCToCSharpTranslator

+ (NSString *)name {
    return @"csharp";
}

- (instancetype)initWithNamespace:(NSString *)namespaceString {
    self = [super init];
    
    if (self) {
        _namespaceString = namespaceString;
    }
    
    return self;
}

- (NSString *)translatedPrefixedIdentifierString:(NSString *)str {
    return [str stringByReplacingOccurrencesOfRegex:[NSString stringWithFormat:@"^%@", self.identifierPrefix]
                                         withString:@""];
}

- (NSString *)translationForUnit:(MPObjectiveCTranslationUnit *)translationUnit {
    MPIndentedMutableString *str = [MPIndentedMutableString new];
    
    if (translationUnit.enumDeclarations.count > 0) {
        [str appendLine:[[NSString alloc] initWithFormat:@"\n// Enum declarations for %@\n\n", translationUnit.path.lastPathComponent]];
        [str appendLine:[self translatedEnumDeclarationsForTranslationUnit:translationUnit]];
        [str appendLine:@"\n"];
    };
    
    if (translationUnit.constantDeclarations.count > 0) {
        [str indent:^{
            [str appendLine:[[NSString alloc] initWithFormat:@"\n// Constant declarations for %@\n\n", translationUnit.path.lastPathComponent]];
            [str appendLine:@"\n"];
        }];
    };
    
    return str.copy;
}

- (NSString *)translatedEnumDeclarationsForTranslationUnit:(MPObjectiveCTranslationUnit *)translationUnit {
    NSMutableString *str = [NSMutableString new];
    
    for (MPObjectiveCEnumDeclaration *enumDeclaration in translationUnit.enumDeclarations) {
        [str appendString:[self translatedEnumDeclaration:enumDeclaration]];
    }
    
    return str.copy;
}

- (NSString *)translatedEnumDeclaration:(MPObjectiveCEnumDeclaration *)declaration {
    MPIndentedMutableString *str = [[MPIndentedMutableString alloc] init];
    
    [str appendLine:
        [[NSString alloc] initWithFormat:@"public enum %@\n",
            [self translatedPrefixedIdentifierString:declaration.name]]];
    [str appendLine:@"{\n"];
    [str indent:^{
        for (NSUInteger i = 0, count = declaration.enumConstants.count; i < count; i++) {
            MPObjectiveCEnumConstant *constant = declaration.enumConstants[i];
            
            [str indent:^{
                BOOL needsCommaSuffix = (declaration.enumConstants.count > 1 && i < declaration.enumConstants.count - 1);
                
                if (constant.value)
                    [str appendLine:[[NSString alloc] initWithFormat:@"%@ = %@", constant.name, constant.value]];
                else
                    [str appendLine:constant.name];
                
                [str appendString:needsCommaSuffix ? @",\n" : @"\n"];
            }];
        }
    }];
    [str appendLine:@"}\n"];
    
    return str.copy;
}

// for string constants:
// http://stackoverflow.com/questions/10055053/exposing-an-obj-c-const-nsstring-via-a-monotouch-binding


@end
