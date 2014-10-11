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
                includedHeaderPaths:(NSArray *)includedHeaders
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

- (void)enumerateCompilationUnits:(void (^)(CKTranslationUnit *unit))unitBlock {
    for (NSString *headerIncludePath in self.includedHeaderPaths) {
        CKTranslationUnit *unit = [[CKTranslationUnit alloc] initWithText:[NSString stringWithContentsOfFile:headerIncludePath encoding:NSUTF8StringEncoding error:nil]
                                                                 language:CKLanguageObjC];
        unitBlock(unit);
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

- (NSDictionary *)enumDeclarationsForHeaderAtPath:(NSString *)includedHeaderPath {
    NSMutableArray *enums = [NSMutableArray new];
    
    __block CKToken *prevToken = prevToken;
    __block MPObjectiveCEnumDeclaration *currentEnum = nil;
    __block MPObjectiveCEnumConstant *currentEnumConstant = nil;
    
    [self enumerateTokensForCompilationUnitAtPath:includedHeaderPath
                                     forEachToken:
     ^(CKTranslationUnit *unit, CKToken *token) {
         
         [self logToken:token headerPath:includedHeaderPath];
         
         if (token.cursor.kind == CKCursorKindEnumDecl) {
             currentEnum = [[MPObjectiveCEnumDeclaration alloc] initWithName:token.cursor.displayName];
             
             NSAssert(![enums containsObject:currentEnum],
                      @"Same enum name should be declared just once in a compilation unit.");
             
             [enums addObject:currentEnum];
         }
         else if (token.cursor.kind == CKCursorKindEnumConstantDecl) {
             currentEnumConstant = [MPObjectiveCEnumConstant new];
             
             NSParameterAssert(currentEnum);
             NSParameterAssert(![currentEnum.enumConstants containsObject:token]);
             
             [currentEnum addEnumConstant:currentEnumConstant];
         }
         else if (token.cursor.kind == CKCursorKindIntegerLiteral) {
             NSAssert(prevToken.kind == CKTokenKindIdentifier
                      && prevToken.cursor.kind == CKCursorKindEnumConstantDecl,
                      @"Integral constant should only follow enum constant declaration.");
             
             MPObjectiveCEnumDeclaration *constant = currentEnum.enumConstants.lastObject;
             NSParameterAssert(constant);
             
             NSNumberFormatter *f = [NSNumberFormatter new];
             f.numberStyle = NSNumberFormatterDecimalStyle;
             NSParameterAssert(token.cursor.displayName.length > 0);
             
             constant.value = [f numberFromString:token.cursor.displayName];
        }
         else {
             NSAssert(false, @"This should be unreachable");
         }
         
         prevToken = token;
    } matchingPattern:
     ^BOOL(NSString *path, CKTranslationUnit *unit, CKToken *token) {
         BOOL isEnum
            = token.kind == CKTokenKindIdentifier
                                && (token.cursor.kind == CKCursorKindEnumConstantDecl
                                    || token.cursor.kind == CKCursorKindEnumDecl);
         
         BOOL isIntegralLiteral
            = token.kind == CKTokenKindLiteral && token.cursor.kind == CKCursorKindIntegerLiteral;
         
         return (isEnum || isIntegralLiteral);
     }];
    
    return enums.copy;
}

- (void)logToken:(CKToken *)token headerPath:(NSString *)headerPath {
    fprintf(stdout, "%s\n",
            [NSString stringWithFormat:@"%@, %lu: %@ (token kind: %lu, cursor kind: %lu, %@)",
             headerPath.lastPathComponent,
             token.line,
             token.cursor.displayName,
             token.kind,
             token.cursor.kind,
             token.cursor.kindSpelling].UTF8String);
}

@end