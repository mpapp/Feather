//
//  MPObjCCSharpTranslator.m
//  Bindings
//
//  Created by Matias Piipari on 11/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import "MPObjectiveCToCSharpTranslator.h"

#import <Feather/RegexKitLite.h>

#import "MPIndentedMutableString.h"

@interface MPObjCToCSharpTranslator ()

@property (readwrite) NSUInteger indentationLevel;

@property (readwrite) MPIndentedMutableString *string;

@end

@implementation MPObjCToCSharpTranslator

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

- (NSString *)translationForUnit:(MPObjCTranslationUnit *)translationUnit {
    MPIndentedMutableString *str = [MPIndentedMutableString new];
    
    if (translationUnit.enumDeclarations.count > 0) {
        [str appendLine:[[NSString alloc] initWithFormat:@"\n// Enum declarations for %@\n\n", translationUnit.path.lastPathComponent]];
        [str appendLine:[self translatedEnumDeclarationsForTranslationUnit:translationUnit]];
        [str appendLine:@"\n"];
    };
    
    if (translationUnit.constantDeclarations.count > 0) {
        [str indent:^{
            [str appendLine:[NSString stringWithFormat:@"\n// Constant declarations for %@\n\n", translationUnit.path.lastPathComponent]];
            [str appendLine:[self translatedConstantDeclarationsForTranslationUnit:translationUnit libraryName:nil]];
            [str appendLine:@"\n"];
        }];
    };
    
    if (translationUnit.classDeclarations.count > 0) {
        [str indent:^{
            [str appendLine:[NSString stringWithFormat:@"\n// Class declarations for %@\n\n", translationUnit.path.lastPathComponent]];
            [str appendLine:[self translatedClassDeclarationsForTranslationUnit:translationUnit]];
            [str appendLine:@"\n"];
            
        }];
    }
    
    return str.copy;
}

- (NSString *)translatedEnumDeclarationsForTranslationUnit:(MPObjCTranslationUnit *)translationUnit {
    NSMutableString *str = [NSMutableString new];
    
    for (MPObjCEnumDeclaration *enumDeclaration in translationUnit.enumDeclarations) {
        [str appendString:[self translatedEnumDeclaration:enumDeclaration]];
    }
    
    return str.copy;
}

- (NSString *)translatedEnumDeclaration:(MPObjCEnumDeclaration *)declaration {
    MPIndentedMutableString *str = [[MPIndentedMutableString alloc] init];
    
    [str appendLine:
        [[NSString alloc] initWithFormat:@"public enum %@\n",
            [self translatedPrefixedIdentifierString:declaration.name]]];
    [str appendLine:@"{\n"];
    [str indent:^{
        for (NSUInteger i = 0, count = declaration.enumConstants.count; i < count; i++) {
            MPObjCEnumConstant *constant = declaration.enumConstants[i];
            
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

- (NSString *)translatedConstantDeclarationsForTranslationUnit:(MPObjCTranslationUnit *)tUnit
                                                   libraryName:(NSString *)libraryName {
    MPIndentedMutableString *str = [MPIndentedMutableString new];
    
    for (MPObjCConstantDeclaration *constDec in tUnit.constantDeclarations) {
        [str appendLine:[self translatedConstantDeclarationForConstantDeclaration:constDec libraryName:libraryName]];
    }
    
    return str.copy;
}

- (NSString *)translatedConstantDeclarationForConstantDeclaration:(MPObjCConstantDeclaration *)cDeclaration
                                                      libraryName:(NSString *)libraryName {
    MPIndentedMutableString *str = [[MPIndentedMutableString alloc] init];
    [str appendLine:[[NSString alloc] initWithFormat:@"[Field (\"%@\", \"%@\")]", cDeclaration.name, libraryName ? libraryName : @"__Internal"]];
    [str appendLine:[[NSString alloc] initWithFormat:@"%@ %@ { get; }", cDeclaration.type, cDeclaration.name]];
    return str.copy;
}

- (NSString *)translatedProtocolDeclarationsForTranslationUnit:(MPObjCTranslationUnit *)tUnit {
    return nil;
}

- (NSString *)translatedProtocolDeclaration:(MPObjCProtocolDeclaration *)propDec {
    return nil;
}

- (NSString *)translatedClassDeclarationsForTranslationUnit:(MPObjCTranslationUnit *)tUnit {
    return nil;
}

- (NSString *)translatedClassDeclaration:(MPObjCClassDeclaration *)declaration {
    MPIndentedMutableString *str = [MPIndentedMutableString new];
    
    [str appendLine:[NSString stringWithFormat:@"[BaseType (typeof (NSObject))"]];
    if ([declaration.superClassName isEqualToString:@"NSObject"]) {
        [str appendLine:@"interface %@"];
    } else {
        [str appendLine:
            [NSString stringWithFormat:
                @"interface %@ : %@", declaration.name, declaration.superClassName]];
    }
    [str appendLine:@"{"];
    
    if (declaration.propertyDeclarations) {
        [str appendLine:[self translatedPropertyDeclarationsForClass:declaration]];
        [str appendLine:@""];
    }
    
    if (declaration.classMethodDeclarations) {
        [str appendLine:[self translatedClassMethodDeclarationsForClass:declaration]];
        [str appendLine:@""];
    }
    
    [str appendLine:@"}"];
    
    return str.copy;
}

- (NSString *)translatedPropertyDeclarationsForClass:(MPObjCClassDeclaration *)classDec {
    MPIndentedMutableString *str = [MPIndentedMutableString new];
    
    for (MPObjCPropertyDeclaration *propDec in classDec.propertyDeclarations) {
        [str appendLine:[self translatedPropertyDeclaration:propDec]];
    }
    
    return str.copy;
}

- (NSString *)translatedPropertyDeclaration:(MPObjCPropertyDeclaration *)propertyDec {
    NSMutableString *str = [NSMutableString stringWithFormat:@"%@ %@ { ", propertyDec.type, propertyDec.name];
    
    if (propertyDec.isReadWrite) {
        [str appendString:@"get; set;"];
    }
    else {
        [str appendString:@"get;"];
    }
    
    return str.copy;
}

- (NSString *)translatedClassMethodDeclarationsForClass:(MPObjCClassDeclaration *)classDec {
    MPIndentedMutableString *str = [MPIndentedMutableString new];
    
    for (MPObjCClassMethodDeclaration *classMethod in classDec.classMethodDeclarations) {
        [str appendString:[self translatedClassMethodDeclarationForClassMethodDeclaration:classMethod]];
    }
    
    return str.copy;
}

- (NSString *)translatedClassMethodDeclarationForClassMethodDeclaration:(MPObjCMethodDeclaration *)classMethod {
    MPIndentedMutableString *str = [MPIndentedMutableString new];

    [str appendLine:[NSString stringWithFormat:@"[Export (\"%@\")", classMethod.selector]];
    
    NSMutableArray *paramStrings = [NSMutableArray new];
    for (MPObjCMethodParameter *param in classMethod.parameters)
        [paramStrings addObject:[NSString stringWithFormat:@"%@ %@", param.type, param.name]];
    NSString *paramString = [paramStrings componentsJoinedByString:@", "];
    
    NSString *methodName = [[classMethod.parameters valueForKey:@"name"] componentsJoinedByString:@""];
    [str appendLine:[NSString stringWithFormat:@"%@ %@(%@);", classMethod.returnType, methodName, paramString]];
    
    return str.copy;
}

- (NSString *)translatedInstanceMethodDeclarationForInstanceMethodDeclaration:(MPObjCInstanceMethodDeclaration *)instanceMethodDec {
    MPIndentedMutableString *str = [MPIndentedMutableString new];
    
    
    
    return str.copy;
}

- (NSString *)translatedInstanceMethodDeclarationsForClass:(MPObjCClassDeclaration *)classDec {
    MPIndentedMutableString *str = [MPIndentedMutableString new];
    
    for (MPObjCInstanceMethodDeclaration *instMethod in classDec.instanceMethodDeclarations) {
        [str appendString:[self translatedInstanceMethodDeclarationForInstanceMethodDeclaration:instMethod]];
    }
    
    return str.copy;
    
}

// for string constants:
// http://stackoverflow.com/questions/10055053/exposing-an-obj-c-const-nsstring-via-a-monotouch-binding


@end
