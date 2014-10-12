//
//  MPObjectiveCTokens.h
//  Bindings
//
//  Created by Matias Piipari on 11/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MPObjectiveCEnumDeclaration, MPObjectiveCEnumConstant;
@class MPObjectiveCMethodDeclaration, MPObjectiveCPropertyDeclaration, MPObjectiveCInstanceVariableDeclaration;

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
@property (readwrite) BOOL isObjectReference;

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


@interface MPObjectiveCClassDeclaration : NSObject

@property (readonly, copy) NSString *name;
@property (readonly, copy) NSString *superClassName;

@property (readonly) NSArray *propertyDeclarations;
@property (readonly) NSArray *methodDeclarations;
@property (readonly) NSArray *instanceVariableDeclarations;

+ (MPObjectiveCClassDeclaration *)classWithName:(NSString *)name;

- (instancetype)initWithName:(NSString *)name superClassName:(NSString *)superClassName;

- (void)addMethodDeclaration:(MPObjectiveCMethodDeclaration *)method;
- (void)addPropertyDeclaration:(MPObjectiveCPropertyDeclaration *)property;
- (void)addInstanceVariableDeclaration:(MPObjectiveCInstanceVariableDeclaration *)ivar;

@end

@interface MPObjectiveCProtocolDeclaration : NSObject

@property (readonly, copy) NSString *name;
@property (readonly, copy) NSArray *conformedProtocols;

@property (readonly) NSArray *propertyDeclarations;
@property (readonly) NSArray *methodDeclarations;

- (void)addConformedProtocol:(NSString *)superProtocol;

- (void)addPropertyDeclaration:(MPObjectiveCPropertyDeclaration *)propDec;
- (void)addMethodDeclaration:(MPObjectiveCMethodDeclaration *)methodDec;

- (instancetype)initWithName:(NSString *)name;

@end

@interface MPObjectiveCPropertyDeclaration : NSObject
@property (readonly, copy) NSString *name;
@property (readonly, copy) NSString *type;

- (instancetype)initWithName:(NSString *)name type:(NSString *)type;

@end

@interface MPObjectiveCInstanceVariableDeclaration : NSObject
@property (readonly, copy) NSString *name;
@property (readonly, copy) NSString *type;

- (instancetype)initWithName:(NSString *)name type:(NSString *)type;

@end

@interface MPObjectiveCMethodDeclaration : NSObject
@property (readonly, copy) NSString *selector;
@property (readonly, copy) NSString *returnType;
@property (readonly, copy) NSArray *argumentTypes;
@property (readonly, copy) NSArray *argumentNames;
@end