//
//  MPObjectiveCTokens.h
//  Bindings
//
//  Created by Matias Piipari on 11/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MPObjectiveCEnumDeclaration, MPObjectiveCEnumConstant;

@interface MPObjectiveCTranslationUnit : NSObject
@property (readonly, copy) NSString *path;

@property (readonly) NSArray *enumDeclarations;

@property (readonly) NSArray *constantDeclarations;

- (instancetype)initWithPath:(NSString *)path;

- (void)addEnumDeclaration:(MPObjectiveCEnumDeclaration *)declaration;

@end

@interface MPObjectiveCEnumDeclaration : NSObject
@property (readonly) NSString *name;
@property (readwrite) NSString *backingType;

@property (readonly, copy) NSArray *enumConstants;

- (instancetype)initWithName:(NSString *)name;

- (void)addEnumConstant:(MPObjectiveCEnumConstant *)enumConstant;

@end

@interface MPObjectiveCConstantDeclaration : NSObject
@property (readonly) NSString *name;
@property (readwrite) id value;
@property (readwrite) NSString *type;

@property (readwrite) BOOL isConst;
@property (readwrite) BOOL isStatic;
@property (readwrite) BOOL isExtern;

- (instancetype)initWithName:(NSString *)name value:(id)value type:(NSString *)type;

@end

@interface MPObjectiveCTyped

@end


@interface MPObjectiveCEnumConstant : NSObject

@property (readonly, weak) MPObjectiveCEnumDeclaration *enumDeclaration;
@property (readonly) NSString *name;
@property (readwrite) NSNumber *value;

- (instancetype)initWithEnumDeclaration:(MPObjectiveCEnumDeclaration *)enumDeclaration
                                   name:(NSString *)name;
@end

