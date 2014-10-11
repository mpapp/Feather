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
#import <Feather/NSFileManager+MPExtensions.h>

#import <ClangKit/ClangKit.h>

#import <dlfcn.h>

@interface MPObjectiveCAnalyzer ()
@property (readwrite) NSBundle *bundle;
@property (readwrite) void *libraryHandle;

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

- (void)logToken:(CKToken *)token headerPath:(NSString *)headerPath {
    fprintf(stdout, "%s\n",
            [NSString stringWithFormat:@"%@, %lu: %@, %@ (token kind: %lu, cursor kind: %lu, %@)",
             headerPath.lastPathComponent,
             token.line,
             token.spelling,
             token.cursor.displayName,
             token.kind,
             token.cursor.kind,
             token.cursor.kindSpelling].UTF8String);
}

@end