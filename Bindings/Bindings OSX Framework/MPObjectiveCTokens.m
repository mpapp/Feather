//
//  MPObjectiveCTokens.m
//  Bindings
//
//  Created by Matias Piipari on 11/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import "MPObjectiveCTokens.h"

@interface MPObjectiveCEnumDeclaration () {
    NSMutableArray *_enumConstants;
}
@end

@interface MPObjectiveCTranslationUnit () {
    NSMutableArray *_enumDeclarations;
}
@end

@implementation MPObjectiveCTranslationUnit

- (instancetype)init {
    return [self initWithPath:nil];
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    
    if (self) {
        _path = path;
        _enumDeclarations = [NSMutableArray new];
    }
    
    return self;
}

- (NSArray *)enumDeclarations {
    return _enumDeclarations.copy;
}

- (void)addEnumDeclaration:(MPObjectiveCEnumDeclaration *)declaration {
    [_enumDeclarations addObject:declaration];
}

@end

@implementation MPObjectiveCEnumDeclaration

- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    
    if (self) {
        _name = name;
        _enumConstants = [NSMutableArray array];
    }
    
    return self;
}

- (NSUInteger)hash {
    return self.name.hash;
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:self.class]
        && [[object name] isEqualToString:self.name];
}

- (void)addEnumConstant:(MPObjectiveCEnumConstant *)enumConstant {
    NSParameterAssert(![self.enumConstants containsObject:enumConstant]);
    [_enumConstants addObject:enumConstant];
}

- (NSArray *)enumConstants {
    return _enumConstants.copy;
}

- (NSString *)description {
    return [NSString stringWithFormat:
                @"[name:%@ backingType:%@ enumConstants:%@]",
            self.name, self.backingType, [self.enumConstants valueForKey:@"description"]];
}

- (NSString *)debugDescription {
    return self.description;
}

@end

#pragma mark - 

@implementation MPObjectiveCConstantDeclaration

- (instancetype)initWithName:(NSString *)name value:(id)value type:(NSString *)type {
    self = [super init];
    
    if (self) {
        _name = name;
        _value = value;
        _type = type;
    }
    
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:
                @"[name:%@ value:%@ type:%@ isStatic:%hhd isConst:%hhd isExtern:%hhd]",
                self.name, self.value, self.type, self.isStatic, self.isConst, self.isExtern];
}

@end

#pragma mark -

@implementation MPObjectiveCEnumConstant

- (instancetype)initWithEnumDeclaration:(MPObjectiveCEnumDeclaration *)enumDeclaration
                                   name:(NSString *)name
{
    self = [super init];
    
    if (self) {
        _enumDeclaration = enumDeclaration;
        _name = name;
    }
    
    return self;
}

- (NSUInteger)hash {
    return self.name.hash;
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:self.class]
        && [[object name] isEqualToString:self.name];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[name:%@ value:%@]", self.name, self.value];
}

- (NSString *)debugDescription {
    return self.description;
}

@end

#pragma mark -

@interface MPObjectiveCClassDeclaration () {
    NSMutableArray *_conformedProtocols;
    NSMutableArray *_propertyDeclarations;
    NSMutableArray *_methodDeclarations;
    NSMutableArray *_instanceVariableDeclarations;
}
@end

@implementation MPObjectiveCClassDeclaration

- (instancetype)init {
    NSAssert(false, @"Use -initWithName:superClassName: instead.");
    return nil;
}

static NSMutableDictionary *_MPObjCClasses = nil;

+ (void)registerClassDeclaration:(MPObjectiveCClassDeclaration *)objcClassDec {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _MPObjCClasses = [NSMutableDictionary new];
    });
    
    NSAssert(!_MPObjCClasses[objcClassDec.name], @"Class '%@' already exists.", objcClassDec.name);
}

+ (MPObjectiveCClassDeclaration *)classWithName:(NSString *)name {
    return _MPObjCClasses[name];
}

- (instancetype)initWithName:(NSString *)name superClassName:(NSString *)superClassName {
    self = [super init];
    
    if (self) {
        _name = name;
        _superClassName = superClassName;
        
        _conformedProtocols = [NSMutableArray new];
        
        _propertyDeclarations = [NSMutableArray new];
        _methodDeclarations = [NSMutableArray new];
        _instanceVariableDeclarations = [NSMutableArray new];
        
    }
    
    return self;
}

- (NSArray *)conformedProtocols {
    return _conformedProtocols.copy;
}

- (NSArray *)methodDeclarations {
    return _methodDeclarations.copy;
}

- (NSArray *)propertyDeclarations {
    return _propertyDeclarations.copy;
}

- (NSArray *)instanceVariableDeclarations {
    return _instanceVariableDeclarations.copy;
}

- (void)addConformedProtocol:(NSString *)conformedProtocol {
    [_conformedProtocols addObject:conformedProtocol];
}

- (void)addMethodDeclaration:(MPObjectiveCMethodDeclaration *)method {
    [_methodDeclarations addObject:method];
}

- (void)addPropertyDeclaration:(MPObjectiveCPropertyDeclaration *)property {
    [_propertyDeclarations addObject:property];
}

- (void)addInstanceVariableDeclaration:(MPObjectiveCInstanceVariableDeclaration *)ivar {
    [_instanceVariableDeclarations addObject:ivar];
}

@end


@interface MPObjectiveCProtocolDeclaration () {
    NSMutableArray *_conformedProtocols;
    NSMutableArray *_methodDeclarations;
    NSMutableArray *_propertyDeclarations;
}
@end

@implementation MPObjectiveCProtocolDeclaration

- (instancetype)init {
    NSAssert(false, @"Use -initWithName: instead.");
    return nil;
}

- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    
    if (self) {
        _name = name;
        _conformedProtocols = [NSMutableArray new];
        _methodDeclarations = [NSMutableArray new];
        _propertyDeclarations = [NSMutableArray new];
    }
    
    return self;
}

- (void)addConformedProtocol:(NSString *)superProtocol {
    [_conformedProtocols addObject:superProtocol];
}

- (void)addMethodDeclaration:(MPObjectiveCMethodDeclaration *)methodDec {
    [_methodDeclarations addObject:methodDec];
}

- (void)addPropertyDeclaration:(MPObjectiveCPropertyDeclaration *)propDec {
    [_propertyDeclarations addObject:propDec];
}

- (NSArray *)conformedProtocols {
    return _conformedProtocols.copy;
}

- (NSArray *)methodDeclarations {
    return _methodDeclarations.copy;
}

- (NSArray *)propertyDeclarations {
    return _propertyDeclarations.copy;
}

@end


@implementation MPObjectiveCPropertyDeclaration

- (instancetype)init {
    NSAssert(false, @"Use -initWithName:type: instead.");
    return nil;
}

- (instancetype)initWithName:(NSString *)name type:(NSString *)type {
    self = [super init];
    
    if (self) {
        _name = name;
        _type = type;
    }
    
    return self;
}

@end


@implementation MPObjectiveCInstanceVariableDeclaration

- (instancetype)init {
    NSAssert(false, @"Use -initWithName:type: instead.");
    return nil;
}

- (instancetype)initWithName:(NSString *)name type:(NSString *)type {
    self = [super init];
    
    if (self) {
        _name = name;
        _type = type;
    }
    
    return self;
}

@end