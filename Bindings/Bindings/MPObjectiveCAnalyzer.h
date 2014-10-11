//
//  MPClassAnalyzer.h
//  Bindings
//
//  Created by Matias Piipari on 10/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CKTranslationUnit, CKToken, CKCursor;

@interface MPObjectiveCAnalyzer : NSObject

@property (readonly) NSArray *includedHeaderPaths;

- (instancetype)initWithDynamicLibraryAtPath:(NSString *)path
                         includedHeaderPaths:(NSArray *)includedHeaders
                                       error:(NSError **)error;

- (instancetype)initWithBundleAtURL:(NSURL *)url
                includedHeaderPaths:(NSArray *)includedHeaders
                              error:(NSError **)error;

- (void)enumerateCompilationUnits:(void (^)(CKTranslationUnit *unit))unitBlock;

- (void)enumerateTokensForCompilationUnitAtPath:(NSString *)path
                                   forEachToken:(void (^)(CKTranslationUnit *unit,
                                                          CKToken *token))tokenBlock
                                matchingPattern:(BOOL (^)(NSString *path,
                                                          CKTranslationUnit *unit,
                                                          CKToken *token))patternBlock;

#pragma mark - 

- (NSDictionary *)enumDeclarationsForHeaderAtPath:(NSString *)includedHeaderPath;

@end
