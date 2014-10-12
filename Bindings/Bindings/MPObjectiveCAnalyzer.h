//
//  MPClassAnalyzer.h
//  Bindings
//
//  Created by Matias Piipari on 10/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CKTranslationUnit, CKToken, CKCursor;
@class MPObjectiveCTranslationUnit;

@interface MPObjectiveCAnalyzer : NSObject

@property (readonly) NSArray *includedHeaderPaths;

- (instancetype)initWithDynamicLibraryAtPath:(NSString *)path
                         includedHeaderPaths:(NSArray *)includedHeaders
                                       error:(NSError **)error;

- (instancetype)initWithObjectiveCHeaderText:(NSString *)header
                       additionalHeaderPaths:(NSArray *)includedHeaders
                                       error:(NSError **)error;

- (instancetype)initWithBundleAtURL:(NSURL *)url
              additionalHeaderPaths:(NSArray *)includedHeaders
                              error:(NSError **)error;

- (MPObjectiveCTranslationUnit *)analyzedTranslationUnitForClangKitTranslationUnit:(CKTranslationUnit *)unit
                                                                            atPath:(NSString *)path;

#pragma mark -

- (void)enumerateTranslationUnits:(void (^)(NSString *path, CKTranslationUnit *unit))unitBlock;

- (void)enumerateTokensForCompilationUnitAtPath:(NSString *)path
                                   forEachToken:(void (^)(CKTranslationUnit *unit, CKToken *token))tokenBlock
                                matchingPattern:(BOOL (^)(NSString *path,
                                                          CKTranslationUnit *unit, CKToken *token))patternBlock;

#pragma mark -

- (NSArray *)enumDeclarationsForHeaderAtPath:(NSString *)includedHeaderPath;

- (NSArray *)constantDeclarationsForHeaderAtPath:(NSString *)includedHeaderPath;

- (NSArray *)classDeclarationsForHeaderAtPath:(NSString *)includedHeaderPath;

- (NSArray *)protocolDeclarationsForHeaderAtPath:(NSString *)includedHeaderPath;

@end
