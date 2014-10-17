//
//  MPObjCTokens.h
//  Bindings
//
//  Created by Matias Piipari on 11/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MPObjCEnumDeclaration, MPObjCEnumConstant, MPObjCConstantDeclaration;
@class MPObjCMethodDeclaration, MPObjCInstanceMethodDeclaration, MPObjCClassMethodDeclaration;
@class MPObjCPropertyDeclaration, MPObjCInstanceVariableDeclaration;
@class MPObjCClassDeclaration;

@interface MPObjCTranslationUnit : NSObject
@property (readonly, copy) NSString *path;

@property (readonly) NSArray *enumDeclarations;

@property (readonly) NSArray *constantDeclarations;

@property (readonly) NSArray *propertyDeclarations;

@property (readonly) NSArray *classDeclarations;

- (instancetype)initWithPath:(NSString *)path;

- (void)addEnumDeclaration:(MPObjCEnumDeclaration *)declaration;

- (void)addConstantDeclaration:(MPObjCConstantDeclaration *)declaration;

- (void)addProtocolDeclaration:(MPObjCPropertyDeclaration *)propDecl;

- (void)addClassDeclaration:(MPObjCClassDeclaration *)classDecl;

@end

@interface MPObjCEnumDeclaration : NSObject
@property (readonly) NSString *name;
@property (readwrite) NSString *backingType;

@property (readonly, copy) NSArray *enumConstants;

- (instancetype)initWithName:(NSString *)name;

- (void)addEnumConstant:(MPObjCEnumConstant *)enumConstant;

@end

@interface MPObjCConstantDeclaration : NSObject
@property (readonly) NSString *name;
@property (readwrite) id value;
@property (readwrite) NSString *type;

@property (readwrite) BOOL isConst;
@property (readwrite) BOOL isStatic;
@property (readwrite) BOOL isExtern;
@property (readwrite) BOOL isObjectReference;

- (instancetype)initWithName:(NSString *)name value:(id)value type:(NSString *)type;

@end

@interface MPObjCEnumConstant : NSObject

@property (readonly, weak) MPObjCEnumDeclaration *enumDeclaration;
@property (readonly) NSString *name;
@property (readwrite) NSNumber *value;

- (instancetype)initWithEnumDeclaration:(MPObjCEnumDeclaration *)enumDeclaration
                                   name:(NSString *)name;
@end

@interface MPObjCTypeDefinition : NSObject

@property (readonly) NSString *name;
@property (readonly) NSString *backingType;

- (instancetype)initWithName:(NSString *)name backingType:(NSString *)backingType;

@end

@interface MPObjCClassDeclaration : NSObject

@property (readonly, copy) NSString *name;
@property (readonly, copy) NSString *superClassName;

@property (readonly) NSArray *conformedProtocols;

@property (readonly) NSArray *propertyDeclarations;
@property (readonly) NSArray *instanceMethodDeclarations;
@property (readonly) NSArray *classMethodDeclarations;
@property (readonly) NSArray *instanceVariableDeclarations;

+ (MPObjCClassDeclaration *)classWithName:(NSString *)name;

- (instancetype)initWithName:(NSString *)name superClassName:(NSString *)superClassName;

- (void)addConformedProtocol:(NSString *)conformedProtocol;

- (void)addInstanceMethodDeclaration:(MPObjCInstanceMethodDeclaration *)method;
- (void)addClassMethodDeclaration:(MPObjCClassMethodDeclaration *)method;

- (void)addPropertyDeclaration:(MPObjCPropertyDeclaration *)property;
- (void)addInstanceVariableDeclaration:(MPObjCInstanceVariableDeclaration *)ivar;

@end

@interface MPObjCProtocolDeclaration : NSObject

@property (readonly, copy) NSString *name;
@property (copy) NSString *type;

@property (readonly, copy) NSArray *conformedProtocols;

@property (readonly) NSArray *classMethodDeclarations;
@property (readonly) NSArray *instanceMethodDeclarations;

- (void)addConformedProtocol:(NSString *)conformedProtocol;

- (void)addPropertyDeclaration:(MPObjCPropertyDeclaration *)propDec;

- (void)addClassMethodDeclaration:(MPObjCClassMethodDeclaration *)methodDec;

- (void)addInstanceMethodDeclaration:(MPObjCInstanceMethodDeclaration *)methodDec;

- (void)addConstantDeclaration:(MPObjCConstantDeclaration *)constDec;

- (instancetype)initWithName:(NSString *)name;

@end

@interface MPObjCPropertyDeclaration : NSObject
@property (readonly, copy) NSString *name;
@property (copy) NSString *type;

@property NSString *ownershipAttribute;
@property BOOL isReadWrite;
@property BOOL isObjectType;
@property NSString *getterName;
@property NSString *setterName;

- (instancetype)initWithName:(NSString *)name type:(NSString *)type;

@end

@interface MPObjCInstanceVariableDeclaration : NSObject
@property (readonly, copy) NSString *name;
@property (readonly, copy) NSString *type;

- (instancetype)initWithName:(NSString *)name type:(NSString *)type;

@end

@interface MPObjCMethodParameter : NSObject
@property (readonly) NSString *name;
@property (readonly) NSString *type;
@property BOOL isObjectType;
@property (readonly) NSString *selectorComponent;

- (instancetype)initWithName:(NSString *)name type:(NSString *)type selectorComponent:(NSString *)selectorComponent;

@end

@interface MPObjCMethodDeclaration : NSObject
@property (readonly, copy) NSString *selector;
@property (readonly, copy) NSString *returnType;
@property (readonly, copy) NSArray *parameters;
@property BOOL returnsObjectType;

- (instancetype)initWithSelector:(NSString *)selector returnType:(NSString *)returnType;

- (void)addParameter:(MPObjCMethodParameter *)param;

@end

@interface MPObjCInstanceMethodDeclaration : MPObjCMethodDeclaration
@end

@interface MPObjCClassMethodDeclaration : MPObjCMethodDeclaration
@end