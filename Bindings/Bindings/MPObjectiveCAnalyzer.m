//
//  MPClassAnalyzer.m
//  Bindings
//
//  Created by Matias Piipari on 10/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import "MPObjectiveCAnalyzer.h"

#import <Cocoa/Cocoa.h>

#import <Bindings/BindingsFramework.h>

#import <Feather/Feather.h>
#import <Feather/NSString+MPExtensions.h>
#import <Feather/NSFileManager+MPExtensions.h>

#import <ClangKit/ClangKit.h>

#import <dlfcn.h>

@interface MPObjectiveCAnalyzer ()
@property (readwrite) NSBundle *bundle;
@property (readwrite) void *libraryHandle;
@property (readwrite) NSString *tempFilePath;

@property (readwrite) NSArray *includedHeaderPaths;

@end


@implementation MPObjectiveCAnalyzer

- (instancetype)initWithDynamicLibraryAtPath:(NSString *)path
                         includedHeaderPaths:(NSArray *)includedHeaders
                                       error:(NSError **)error {
    self = [super init];
    
    if (self) {
        _libraryHandle = dlopen(path.UTF8String, RTLD_LAZY);
        _includedHeaderPaths = includedHeaders;
    }
    
    return self;
}

- (instancetype)initWithObjectiveCHeaderText:(NSString *)header
                       additionalHeaderPaths:(NSArray *)includedHeaders
                                       error:(NSError **)error {
    
    _tempFilePath = [[[NSFileManager defaultManager] temporaryFileURLInApplicationCachesSubdirectoryNamed:@"bindings-headers"
                                                                                            withExtension:@"h"
                                                                                                    error:error] path];
    
    if (!_tempFilePath)
        return nil;
    
    if (![header writeToFile:_tempFilePath
                  atomically:YES
                    encoding:NSUTF8StringEncoding
                       error:error])
        return nil;

    self = [super init];
    
    if (self) {
        _includedHeaderPaths = [@[_tempFilePath] arrayByAddingObjectsFromArray:includedHeaders];
    }
    
    return self;
}

- (instancetype)initWithBundleAtURL:(NSURL *)url
              additionalHeaderPaths:(NSArray *)includedHeaders
                              error:(NSError **)error {
    self = [super init];
    
    if (self) {
        _bundle = [[NSBundle alloc] initWithURL:url];
        if (![_bundle loadAndReturnError:error])
            return nil;
        
        _includedHeaderPaths
            = [[NSFileManager defaultManager]
                recursivePathsForResourcesOfType:@"h" inDirectory:_bundle.bundlePath];
        
        if (includedHeaders)
            _includedHeaderPaths
                = [_includedHeaderPaths arrayByAddingObjectsFromArray:includedHeaders];
    }
    
    return self;
}

- (void)dealloc {
    NSError *err = nil;
    if (_tempFilePath) {
        if (![[NSFileManager defaultManager] removeItemAtPath:_tempFilePath error:&err]) {
            NSLog(@"WARNING! Failed to delete temporary file at path '%@'.", _tempFilePath);
        }
    }
}

// for each translation unit

// 2) get its constant declarations

// 3) get its interface declarations

// 4) get its protocol declarations

// 5)for each interface found
// 5a) get its class object using runtime API
// 5b) enumerate its properties
// 5c) enumerate its instance variables
// 5d) enumerate its class methods
// 5e) enumerate its instance methods

// 6) for each protocol found
// 6a) get its Protocol object using runtime API
// 6b) enumerate its properties
// 6c) enumerate its instance variables
// 6d) enumerate its class methods
// 6e) enumerate its instance methods

- (MPObjectiveCTranslationUnit *)analyzedTranslationUnitForClangKitTranslationUnit:(CKTranslationUnit *)unit
                                                                            atPath:(NSString *)path {
    MPObjectiveCTranslationUnit *analyzedUnit = [[MPObjectiveCTranslationUnit alloc] initWithPath:path];
    
    // 1) get enum declarations
    for (MPObjectiveCEnumDeclaration *declaration in [self enumDeclarationsForHeaderAtPath:path])
        [analyzedUnit addEnumDeclaration:declaration];
    
    return analyzedUnit;
}

#pragma mark -

- (void)enumerateTranslationUnits:(void (^)(NSString *path, CKTranslationUnit *unit))unitBlock {
    for (NSString *headerIncludePath in self.includedHeaderPaths) {
        NSError *err = nil;
        
        NSLog(@"Header include path: %@", headerIncludePath);
        CKTranslationUnit *unit = [[CKTranslationUnit alloc] initWithText:[NSString stringWithContentsOfFile:headerIncludePath encoding:NSUTF8StringEncoding error:&err] language:CKLanguageObjC];
        
        NSAssert(!err, @"An error occurred when parsing %@: %@", headerIncludePath, err);
        
        unitBlock(headerIncludePath, unit);
    }
}

- (void)enumerateTokensForCompilationUnitAtPath:(NSString *)path
                                   forEachToken:(void (^)(CKTranslationUnit *unit, CKToken *token))tokenBlock
        matchingPattern:(BOOL (^)(NSString *path, CKTranslationUnit *unit, CKToken *token))patternBlock {
    
    CKTranslationUnit *unit = [[CKTranslationUnit alloc]
                               initWithText:[NSString stringWithContentsOfFile:path
                                                                      encoding:NSUTF8StringEncoding
                                                                         error:nil]
                               language:CKLanguageObjC];
    
    [unit.tokens enumerateObjectsUsingBlock:
     ^(CKToken *token, NSUInteger idx, BOOL *stop) {
         if (patternBlock(path, unit, token))
             tokenBlock(unit, token);
    }];
}

#pragma mark -

- (NSArray *)typeDefinitionsForHeaderAtPath:(NSString *)includedHeaderPath {
    NSMutableArray *typedefs = [NSMutableArray new];
    
    [self enumerateTokensForCompilationUnitAtPath:includedHeaderPath forEachToken:
     ^(CKTranslationUnit *unit, CKToken *token)
    {
        
    } matchingPattern:^BOOL(NSString *path, CKTranslationUnit *unit, CKToken *token)
    {
        [self logToken:token headerPath:path];
        
        return token.cursor.kind == CKCursorKindTypeAliasDecl
            || token.cursor.kind == CKCursorKindTypedefDecl;
    }];
    
    return typedefs.copy;
}

- (NSArray *)enumDeclarationsForHeaderAtPath:(NSString *)includedHeaderPath {
    NSMutableArray *enums = [NSMutableArray new];
    
    __block CKToken *prevToken = prevToken;
    __block MPObjectiveCEnumDeclaration *currentEnum = nil;
    __block MPObjectiveCEnumConstant *currentEnumConstant = nil;
    
    NSMutableArray *currentMacroExpansions = [NSMutableArray new];
    
    [self enumerateTokensForCompilationUnitAtPath:includedHeaderPath
                                     forEachToken:
     ^(CKTranslationUnit *unit, CKToken *token) {
         
         if (token.cursor.kind == CKCursorKindMacroExpansion) {
             
             // append to currentMacroExpansions only if the identifier is NS_ENUM
             // or if there is already a macro expansion being expanded.
             if (([token.spelling isEqualToString:@"NS_ENUM"]
                 || currentMacroExpansions.count > 0)
                 && ![currentMacroExpansions containsObject:token.spelling]) {
                 [currentMacroExpansions addObject:token.spelling];
             }
         }
         else if (token.cursor.kind == CKCursorKindEnumDecl) {
             
             MPObjectiveCEnumDeclaration *cursorEnum = [[MPObjectiveCEnumDeclaration alloc] initWithName:token.cursor.displayName];
             
             // should be something like:
             // <__NSArrayM 0x10034dc20>(
             // NS_ENUM,
             // NSUInteger,
             // MPFoobar)
             if (currentMacroExpansions.count == 3) {
                 NSParameterAssert([currentMacroExpansions.firstObject isEqualToString:@"NS_ENUM"]);
                 NSParameterAssert([currentMacroExpansions.lastObject isEqualToString:token.cursor.displayName]);
                 cursorEnum.backingType = currentMacroExpansions[1];
             }
             else {
                 NSLog(@"WARNING! Ignoring enum declaration '%@' as it doesn't appear to be defined with NS_ENUM.",
                       token.cursor.displayName);
                 return;
             }

             if ([cursorEnum isEqual:currentEnum])
                 return;
             
             currentEnum = cursorEnum;
             
             [currentMacroExpansions removeAllObjects];
             
             NSAssert(![enums containsObject:currentEnum],
                      @"Same enum name should be declared just once in a compilation unit.");
             
             [enums addObject:currentEnum];
         }
         else if (token.cursor.kind == CKCursorKindEnumConstantDecl) {
             
             if (!currentEnum) {
                 NSLog(@"WARNING! Ignoring enum constant declaration %@", token.cursor.displayName);
                 return;
             }
             
             NSParameterAssert(currentEnum);
             NSParameterAssert(![currentEnum.enumConstants containsObject:token]);
             currentEnumConstant = [[MPObjectiveCEnumConstant alloc] initWithEnumDeclaration:currentEnum name:token.cursor.displayName];
             
             [currentEnum addEnumConstant:currentEnumConstant];
         }
         else if (token.cursor.kind == CKCursorKindIntegerLiteral) {
             
             // this is an unrelated integral constant.
             if (!currentEnum)
                 return;
             
             NSAssert(prevToken.kind == CKTokenKindIdentifier
                      && prevToken.cursor.kind == CKCursorKindEnumConstantDecl,
                      @"Integral constant should only follow enum constant declaration.");
         
             MPObjectiveCEnumDeclaration *constant = currentEnum.enumConstants.lastObject;
             NSParameterAssert(constant);
             
             NSNumberFormatter *f = [NSNumberFormatter new];
             f.numberStyle = NSNumberFormatterDecimalStyle;
             //NSParameterAssert();
             
             if (token.spelling.length > 0) {
                 constant.value = [f numberFromString:token.spelling];
             }
        }
         else {
             NSAssert(false, @"This should be unreachable");
         }
         
         prevToken = token;
    } matchingPattern:
     ^BOOL(NSString *path, CKTranslationUnit *unit, CKToken *token) {
         //[self logToken:token headerPath:path];
         
         BOOL isEnumDeclaration = (token.kind == CKTokenKindPunctuation && token.cursor.kind == CKCursorKindEnumDecl);
         BOOL isEnumConstDeclaration = (token.kind == CKTokenKindIdentifier && token.cursor.kind == CKCursorKindEnumConstantDecl);
         
         BOOL isIntegralLiteral
            = token.kind == CKTokenKindLiteral
            && token.cursor.kind == CKCursorKindIntegerLiteral;
         
         BOOL isIdentifierMacroExpansion
             = token.kind == CKTokenKindIdentifier
            && token.cursor.kind == CKCursorKindMacroExpansion;
         
         BOOL returnVal = (isEnumDeclaration || isEnumConstDeclaration || isIntegralLiteral || isIdentifierMacroExpansion);
         
         //if (returnVal)
         //    [self logToken:token headerPath:path];
         
         return returnVal;
     }];
    
    return enums.copy;
}

- (NSArray *)constantDeclarationsForHeaderAtPath:(NSString *)includedHeaderPath {
    NSMutableArray *constants = [NSMutableArray new];
    
    __block NSUInteger prevLine = NSNotFound;
    __block NSString *currentType = nil;
    __block MPObjectiveCConstantDeclaration *currentConst = nil;
    __block CKToken *prevToken = nil;
    __block BOOL currentDeclarationIsObjectType = NO;
    
    NSMutableArray *currentVarDeclarationKeywords = [NSMutableArray new];
    
    [self enumerateTokensForCompilationUnitAtPath:includedHeaderPath
                                     forEachToken:^(CKTranslationUnit *unit, CKToken *token)
    {
        // FIXME: don't assume a constant definition is on a single line (you can use the semanticParent property for that).
        if (prevLine == NSNotFound || prevLine != token.line) {
            prevLine = token.line;
            
            currentType = nil;
            currentConst = nil;
            currentDeclarationIsObjectType = NO;
            [currentVarDeclarationKeywords removeAllObjects];
        }
        
        if (token.kind == CKTokenKindKeyword
            && token.cursor.kind == CKCursorKindVarDecl) {
            
            // FIME: reset the keyword stack on new source locations / lines.
            [currentVarDeclarationKeywords addObject:token.spelling];
        }
        else if (token.kind == CKTokenKindIdentifier
                 && token.cursor.kind == CKCursorKindTypeRef) {
            currentType = token.spelling;
        }
        else if (token.cursor.kind == CKCursorKindObjCClassRef) {
            currentType = token.spelling;
            currentDeclarationIsObjectType = YES;
        } // FIXME: handle const * NSString and NSString * const correctly.  
        else if (token.kind == CKTokenKindIdentifier && token.cursor.kind == CKCursorKindVarDecl) {
            
            if (currentVarDeclarationKeywords.count == 0 || !currentType)
                return;
            
            currentConst = [[MPObjectiveCConstantDeclaration alloc] initWithName:token.spelling value:nil
                                                                            type:currentType];
            
            [constants addObject:currentConst];
            
            if ([currentVarDeclarationKeywords containsObject:@"static"])
                currentConst.isStatic = YES;
            
            if ([currentVarDeclarationKeywords containsObject:@"const"])
                currentConst.isConst = YES;
            
            if ([currentVarDeclarationKeywords containsObject:@"extern"])
                currentConst.isExtern = YES;
            
            currentConst.isObjectReference = YES;
            
            [currentVarDeclarationKeywords removeAllObjects];
            currentType = nil;
        }
        else if (token.kind == CKTokenKindLiteral && token.cursor.kind == CKCursorKindIntegerLiteral) {
            NSNumberFormatter *f = [NSNumberFormatter new];
            f.numberStyle = NSNumberFormatterDecimalStyle;
            currentConst.value = [f numberFromString:token.spelling];
            
            currentConst = nil;
        }
        else if (token.kind == CKTokenKindLiteral && token.cursor.kind == CKCursorKindFloatingLiteral) {
            currentConst.value = @([token.spelling floatValue]); // FIXME: this is ridiculously simplistic.
        }
        else if (token.kind == CKTokenKindLiteral && token.cursor.kind == CKCursorKindStringLiteral) {
            currentConst.value = token.spelling;
        }
        // FIXME: handle constants that refer to other constants.
        // FIXME: handle character constants.
        
        prevToken = token;
        
    } matchingPattern:^BOOL(NSString *path, CKTranslationUnit *unit, CKToken *token) {
        //[self logToken:token headerPath:path];

        // BDSKErrorObject.h, 43: const, MPSlappedSalmon (token kind: 1, cursor kind: 9, VarDecl)
        // BDSKErrorObject.h, 43: static, MPSlappedSalmon (token kind: 1, cursor kind: 9, VarDecl)
        BOOL isVariableDeclaration = (token.kind == CKTokenKindKeyword && token.cursor.kind == CKCursorKindVarDecl);
        
        // BDSKErrorObject.h, 43: NSUInteger, NSUInteger (token kind: 2, cursor kind: 43, TypeRef)
        BOOL isTypeReference = token.kind == CKTokenKindIdentifier && token.cursor.kind == CKCursorKindTypeRef;
        
        // BDSKErrorObject.h, 43: MPSlappedSalmon, MPSlappedSalmon (token kind: 2, cursor kind: 9, VarDecl)
        // BDSKErrorObject.h, 43: =, MPSlappedSalmon (token kind: 0, cursor kind: 9, VarDecl)
        BOOL isVarIdentifier = token.kind == CKTokenKindIdentifier && token.cursor.kind == CKCursorKindVarDecl;
        
        // BDSKErrorObject.h, 43: 42,  (token kind: 3, cursor kind: 106, IntegerLiteral)
        BOOL isIntegralLiteralValue = token.kind == CKTokenKindLiteral && token.cursor.kind == CKCursorKindIntegerLiteral;
        
        BOOL isClassRef = token.kind == CKTokenKindIdentifier && token.cursor.kind == CKCursorKindObjCClassRef;
        
        BOOL isVarDeclPunctuation
            = token.kind == CKTokenKindPunctuation
            && token.cursor.kind == CKCursorKindVarDecl
            && token.cursor.semanticParent.kind == CKCursorKindVarDecl
            && [token.spelling isEqualToString:@"*"];
        
        if (isVarDeclPunctuation) {
            NSLog(@"PUNCTUATION SEMANTIC PARENT: %@", token.cursor.semanticParent);
        }
        
        
        return isVariableDeclaration
            || isTypeReference
            || isVarIdentifier
            || isIntegralLiteralValue
            || isClassRef
            || isVarDeclPunctuation;
    }];
    
    return constants.copy;
}

- (NSArray *)classDeclarationsForHeaderAtPath:(NSString *)includedHeaderPath {
    NSMutableArray *classes = [NSMutableArray new];
    
    __block NSString *currentClassName = nil;
    __block MPObjectiveCClassDeclaration *currentClass = nil;
    __block NSMutableArray *currentClassPunctuation = [NSMutableArray new];
    
    __block NSString *currentPropertyName = nil;
    __block BOOL currentPropertyIsReadwrite = YES;
    __block BOOL currentPropertyIsObjectType = NO;
    __block NSString *currentPropertyType = nil;
    __block NSString *currentPropertyOwnership = nil;
    __block NSString *currentPropertyGetterName = nil;
    __block NSString *currentPropertySetterName = nil;
    
    
    __block MPObjectiveCPropertyDeclaration *currentPropertyDec = nil;
    __block NSMutableArray *currentPropertyPunctuation = [NSMutableArray new];
    __block NSMutableArray *currentPropertyIdentifiers = [NSMutableArray new];
    __block NSMutableArray *currentPropertyAttributeIdentifiers = [NSMutableArray new];
    
    
    __block MPObjectiveCMethodDeclaration *currentMethodDec = nil;
    __block BOOL currentMethodIsClassMethod = NO;
    __block NSMutableArray *currentMethodPunctuation = [NSMutableArray new];
    __block NSMutableArray *currentMethodIdentifiers = [NSMutableArray new];
    __block NSMutableArray *currentMethodSelectorComponents = [NSMutableArray new];
    __block NSMutableArray *currentMethodParamTypes = [NSMutableArray new];
    __block NSMutableArray *currentMethodParamNames = [NSMutableArray new];
    __block NSString *currentMethodSelector = nil;
    
    [self enumerateTokensForCompilationUnitAtPath:includedHeaderPath
                                     forEachToken:^(CKTranslationUnit *unit, CKToken *token)
    {
        if (token.cursor.kind == CKCursorKindObjCInterfaceDecl) {
            // we're at the '@' -- reset the current state
            if ([token.spelling isEqualToString:@"@"]) {
                currentClassName = nil;
                currentClass = nil;
                [currentClassPunctuation removeAllObjects];
                [currentPropertyIdentifiers removeAllObjects];
                [currentPropertyAttributeIdentifiers removeAllObjects];
                
                [currentClassPunctuation addObject:token.spelling];
                return;
            }
            
            if (token.kind == CKTokenKindPunctuation)
                [currentClassPunctuation addObject:token.spelling];
            
            if (![currentClassPunctuation containsObject:@":"]) {
                if (token.kind == CKTokenKindIdentifier)  // class name
                    currentClassName = token.spelling;
                
            } else if (![currentClassPunctuation containsObject:@"<"]) { // beyond class name, not yet in protocol conformance declarations
                
                if (token.kind == CKTokenKindIdentifier) {
                    currentClass = [[MPObjectiveCClassDeclaration alloc] initWithName:currentClassName
                                                                       superClassName:token.spelling];
                    
                    [classes addObject:currentClass];
                }
                
            } else { // we're in the protocol declarations
                
                if (token.kind == CKTokenKindIdentifier) {
                    NSParameterAssert(currentClass);
                    [currentClass addConformedProtocol:token.spelling];
                }
            }
        }
        
        if (token.cursor.kind == CKCursorKindObjCPropertyDecl) {
            
            // beginning of the line has the token '%@' - use it to reset state.
            if ([token.spelling isEqualToString:@"@"]) {
                currentPropertyDec = nil;
                
                currentPropertyName = nil;
                currentPropertyIsReadwrite = YES;
                currentPropertyIsObjectType = NO;
                
                currentPropertyType = nil;
                currentPropertyOwnership = nil;
                currentPropertyGetterName = nil;
                currentPropertySetterName = nil;
                
                [currentPropertyPunctuation removeAllObjects];
                [currentPropertyIdentifiers removeAllObjects];
                
                [currentPropertyPunctuation addObject:token.spelling];
                return;
            }
            
            if (token.kind == CKTokenKindPunctuation) {
                if ([token.spelling isEqualToString:@"*"]) {
                    currentPropertyIsObjectType = YES;
                }
                
                [currentPropertyPunctuation addObject:token.spelling];
            }
            
            BOOL attributesClosed = ([currentPropertyPunctuation containsObject:@"("]
                                  && [currentPropertyPunctuation containsObject:@")"]);
            BOOL hasNoAttributes = (![currentPropertyPunctuation containsObject:@"("]
                                    && ![currentPropertyPunctuation containsObject:@")"]);
            
            if (attributesClosed || hasNoAttributes) {
                
                if (token.kind == CKTokenKindIdentifier) {
                    [currentPropertyIdentifiers addObject:token.spelling];
                    
                    if (currentPropertyIdentifiers.count == 2) {
                        currentPropertyDec = [[MPObjectiveCPropertyDeclaration alloc] initWithName:currentPropertyIdentifiers[1]
                                                                                          type:currentPropertyIdentifiers[0]];
                        currentPropertyDec.isReadWrite = currentPropertyIsReadwrite;
                        currentPropertyDec.isObjectType = currentPropertyIsObjectType;
                        currentPropertyDec.ownershipAttribute = currentPropertyOwnership;
                        currentPropertyDec.getterName = currentPropertyGetterName;
                        currentPropertyDec.setterName = currentPropertySetterName;
                        [currentClass addPropertyDeclaration:currentPropertyDec];
                    }
                }
            }
            else if ([currentPropertyPunctuation containsObject:@"("]) {
                
                if (token.kind == CKTokenKindIdentifier) {
                    [currentPropertyAttributeIdentifiers addObject:token.spelling];

                    if ([token.spelling isEqualToString:@"readwrite"])
                        currentPropertyIsReadwrite = YES;
                    else if ([token.spelling isEqualToString:@"readonly"])
                        currentPropertyIsReadwrite = NO;
                    else if ([@[@"copy", @"assign", @"weak", @"strong", @"retain"] containsObject:token.spelling])
                        currentPropertyOwnership = token.spelling;
                    
                    // detect case of 'setter = x' where x is the current token
                    else if ([[currentPropertyPunctuation lastObject] isEqualToString:@"="]
                             && (currentPropertyAttributeIdentifiers.count > 1
                                 && [currentPropertyAttributeIdentifiers[currentPropertyAttributeIdentifiers.count - 2] isEqualToString:@"setter"]))
                    {
                        currentPropertySetterName = token.spelling;
                    }
                    // detect case of 'getter = x' where x is the current token
                    else if ([[currentPropertyPunctuation lastObject] isEqualToString:@"="]
                             && (currentPropertyAttributeIdentifiers.count > 1
                                 && [currentPropertyAttributeIdentifiers[currentPropertyAttributeIdentifiers.count - 2] isEqualToString:@"getter"]))
                    {
                        currentPropertyGetterName = token.spelling;
                    }
                }
            }
        }
        
        else if (token.cursor.kind == CKCursorKindObjCInstanceMethodDecl
                 || token.cursor.kind == CKCursorKindObjCClassMethodDecl) {
            
            if (token.kind == CKTokenKindPunctuation &&
                ([token.spelling isEqualToString:@"-"] || [token.spelling isEqualToString:@"+"])) {
                currentMethodDec = nil;
                currentMethodPunctuation = [NSMutableArray new];
                currentMethodIdentifiers = [NSMutableArray new];
                currentMethodParamNames = [NSMutableArray new];
                currentMethodParamTypes = [NSMutableArray new];
                currentMethodSelectorComponents = [NSMutableArray new];
                
                currentMethodIsClassMethod = [token.spelling isEqualToString:@"+"];
                currentMethodSelector = token.cursor.displayName.copy;
                
                [currentMethodPunctuation addObject:token.spelling];
                return;
            }
            
            if (token.kind == CKTokenKindPunctuation)
                [currentMethodPunctuation addObject:token.spelling];
            
            // capture the "- (X" case where X is current token and represents the return type.
            // made specific to the first one as only a single method declaration is made.
            if (!currentMethodDec
                && token.kind == CKTokenKindIdentifier
                && [currentMethodPunctuation containsObject:@"("]
                && ![currentMethodPunctuation containsObject:@")"]) {
                
                currentMethodDec = [[(currentMethodIsClassMethod
                                      ? MPObjectiveCClassMethodDeclaration.class
                                      : MPObjectiveCInstanceMethodDeclaration.class) alloc]
                                    initWithSelector:currentMethodSelector returnType:token.spelling];
                
                if (currentMethodIsClassMethod) {
                    [currentClass addClassMethodDeclaration:(id)currentMethodDec];
                }
                else {
                    [currentClass addInstanceMethodDeclaration:(id)currentMethodDec];
                }
            }
            else {
                if (token.kind == CKTokenKindIdentifier)
                    [currentMethodIdentifiers addObject:token.spelling];
            }
        }
        
        //&& (token.cursor.semanticParent.semanticParent.kind == CKCursorKindObjCClassMethodDecl
        //    || token.cursor.semanticParent.semanticParent.kind == CKCursorKindObjCInstanceMethodDecl)
        else if (currentMethodSelector && token.cursor.kind == CKCursorKindParmDecl) {
            
            NSUInteger openingBraceCount = 0;
            NSUInteger closingBraceCount = 0;
            
            for (NSUInteger i = 0, count = currentMethodPunctuation.count; i < count; i++) {
                NSString *punk = currentMethodPunctuation[i];
                
                if ([punk isEqualToString:@"("])
                    openingBraceCount++;
                if ([punk isEqualToString:@")"])
                    closingBraceCount++;
            }
            
            // brace count would be 1 for opening & closing after the return type braces.
            BOOL paramBracesOpened = (openingBraceCount > 1) && (closingBraceCount > 1);
            
            // this is to ensure we're not presently inside a param definition
            BOOL paramBracesBalanced = (openingBraceCount % 2 == 0) && (closingBraceCount % 2 == 0);
            
            if (currentMethodDec && paramBracesOpened && paramBracesBalanced) {
                
                // assuming second last identifier is a selector component preceding the parameter. this may be too simplistic.
                NSString *selectorComponent = currentMethodIdentifiers[currentMethodIdentifiers.count - 2];

                NSAssert([currentMethodSelector containsSubstring:selectorComponent],
                         @"Selector '%@' should contain component '%@'", currentMethodSelector, selectorComponent);
                
                // assuming last identifier is the type identifier. this may be too simplistic.
                NSString *paramType = currentMethodIdentifiers.lastObject;
                
                [currentMethodParamNames addObject:token.spelling];
                
                [currentMethodDec addParameter:[[MPObjectiveCMethodParameter alloc]
                                                initWithName:token.spelling
                                                type:paramType
                                                selectorComponent:selectorComponent]];
            }
        }
        else if (currentMethodSelector && token.cursor.kind == CKCursorKindTypeRef)
        {
            currentMethodDec = [[(currentMethodIsClassMethod
                                  ? MPObjectiveCClassMethodDeclaration.class
                                  : MPObjectiveCInstanceMethodDeclaration.class) alloc]
                                initWithSelector:currentMethodSelector returnType:token.spelling];
            
            if (currentMethodIsClassMethod) {
                [currentClass addClassMethodDeclaration:(id)currentMethodDec];
            }
            else {
                [currentClass addInstanceMethodDeclaration:(id)currentMethodDec];
            }
        }
    } matchingPattern:^BOOL(NSString *path, CKTranslationUnit *unit, CKToken *token) {
        //[self logToken:token headerPath:path];
        
        BOOL isInterfaceIdentifierToken = token.kind == CKTokenKindIdentifier
            && token.cursor.kind == CKCursorKindObjCInterfaceDecl;
        
        BOOL isInterfacePunctuation = token.kind == CKTokenKindPunctuation
            && token.cursor.kind == CKCursorKindObjCInterfaceDecl;
        
        BOOL isPropertyIdentifierToken = token.kind == CKTokenKindIdentifier && token.cursor.kind == CKCursorKindObjCPropertyDecl;
        BOOL isPropertyPunctuation = token.kind == CKTokenKindPunctuation && token.cursor.kind == CKCursorKindObjCPropertyDecl;
        BOOL isPropertyKeyword = token.kind == CKTokenKindKeyword && token.cursor.kind == CKCursorKindObjCPropertyDecl;
        
        BOOL isMethodIdentifierToken = token.kind == CKTokenKindIdentifier
            && (token.cursor.kind == CKCursorKindObjCInstanceMethodDecl || token.cursor.kind == CKCursorKindObjCClassMethodDecl);
        BOOL isMethodPunctuation = token.kind == CKTokenKindPunctuation
            && (token.cursor.kind == CKCursorKindObjCInstanceMethodDecl || token.cursor.kind == CKCursorKindObjCClassMethodDecl);
        BOOL isParameterToken = token.kind == CKTokenKindIdentifier && token.cursor.kind == CKCursorKindParmDecl;
        BOOL isTypeRefToken = token.kind == CKTokenKindIdentifier && token.cursor.kind == CKCursorKindTypeRef;
        
        return isInterfaceIdentifierToken
            || isInterfacePunctuation
            || isPropertyIdentifierToken
            || isPropertyPunctuation
            || isPropertyKeyword
            || isMethodIdentifierToken
            || isMethodPunctuation
            || isParameterToken
            || isTypeRefToken;
    }];
    
    return classes.copy;
}

- (void)logToken:(CKToken *)token headerPath:(NSString *)headerPath {
    fprintf(stdout, "%s\n",
            [NSString stringWithFormat:
             @"%@, %lu: %@, %@ (token kind: %lu, cursor kind: %lu, %@; semantic parent:%lu, %@; lexical parent:%lu, %@)",
             headerPath.lastPathComponent,
             token.line,
             token.spelling,
             token.cursor.displayName,
             token.kind,
             token.cursor.kind,
             token.cursor.kindSpelling,
             token.cursor.semanticParent.kind,
             token.cursor.semanticParent.kindSpelling,
             token.cursor.lexicalParent.kind,
             token.cursor.lexicalParent.kindSpelling].UTF8String);
}

@end