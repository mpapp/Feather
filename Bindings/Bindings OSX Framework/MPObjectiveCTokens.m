//
//  MPObjCTokens.m
//  Bindings
//
//  Created by Matias Piipari on 11/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import "MPObjectiveCTokens.h"

@interface MPObjCEnumDeclaration () {
    NSMutableArray *_enumConstants;
}
@end

@interface MPObjCTranslationUnit () {
    NSMutableArray *_enumDeclarations;
}
@end

@implementation MPObjCTranslationUnit

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

- (void)addEnumDeclaration:(MPObjCEnumDeclaration *)declaration {
    [_enumDeclarations addObject:declaration];
}

@end

@implementation MPObjCEnumDeclaration

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

- (void)addEnumConstant:(MPObjCEnumConstant *)enumConstant {
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

@implementation MPObjCTypeDefinition

- (instancetype)init {
    NSAssert(false, @"Use -initWithName:backingType: instead.");
    return nil;
}

- (instancetype)initWithName:(NSString *)name backingType:(NSString *)backingType {
    self = [super init];
    
    if (self) {
        _name = name;
        _backingType = backingType;
    }
    
    return self;
}

static NSMutableDictionary *types = nil;

+ (void)registerType:(MPObjCTypeDefinition *)typeDef {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = [NSMutableDictionary new];
    });
    
    types[typeDef.name] = typeDef;
}

+ (MPObjCTypeDefinition *)typeWithName:(NSString *)name {
    MPObjCTypeDefinition *backingType = types[name];
    NSAssert(backingType, @"No type with name '%@'", name);
    while (true) {
        MPObjCTypeDefinition *prevType = backingType; // FIXME: handle hierarchies of typedefs going back all the way to a basic type
        backingType = types[backingType.name];
    }
}

- (NSUInteger)hash {
    return _name.hash;
}

- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:MPObjCTypeDefinition.class]
        && [_name isEqualToString:[object name]];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[name:%@ backingType:%@]", self.name, self.backingType];
}

@end

#pragma mark - 

@implementation MPObjCConstantDeclaration

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

@implementation MPObjCEnumConstant

- (instancetype)initWithEnumDeclaration:(MPObjCEnumDeclaration *)enumDeclaration
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

@interface MPObjCClassDeclaration () {
    NSMutableArray *_conformedProtocols;
    NSMutableArray *_propertyDeclarations;
    NSMutableArray *_instanceMethodDeclarations;
    NSMutableArray *_classMethodDeclarations;
    NSMutableArray *_instanceVariableDeclarations;
}
@end

@implementation MPObjCClassDeclaration

- (instancetype)init {
    NSAssert(false, @"Use -initWithName:superClassName: instead.");
    return nil;
}

static NSMutableDictionary *_MPObjCClasses = nil;

+ (void)registerClassDeclaration:(MPObjCClassDeclaration *)objcClassDec {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _MPObjCClasses = [NSMutableDictionary new];
    });
    
    NSAssert(!_MPObjCClasses[objcClassDec.name], @"Class '%@' already exists.", objcClassDec.name);
}

+ (MPObjCClassDeclaration *)classWithName:(NSString *)name {
    return _MPObjCClasses[name];
}

- (instancetype)initWithName:(NSString *)name superClassName:(NSString *)superClassName {
    self = [super init];
    
    if (self) {
        _name = name;
        _superClassName = superClassName;
        
        _conformedProtocols = [NSMutableArray new];
        
        _propertyDeclarations = [NSMutableArray new];
        _instanceMethodDeclarations = [NSMutableArray new];
        _classMethodDeclarations = [NSMutableArray new];
        _instanceVariableDeclarations = [NSMutableArray new];
        
    }
    
    return self;
}

- (NSArray *)conformedProtocols {
    return _conformedProtocols.copy;
}

- (NSArray *)instanceMethodDeclarations {
    return _instanceMethodDeclarations.copy;
}

- (NSArray *)classMethodDeclarations {
    return _classMethodDeclarations.copy;
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

- (void)addInstanceMethodDeclaration:(MPObjCMethodDeclaration *)method {
    [_instanceMethodDeclarations addObject:method];
}

- (void)addClassMethodDeclaration:(MPObjCClassMethodDeclaration *)method {
    [_classMethodDeclarations addObject:method];
}

- (void)addPropertyDeclaration:(MPObjCPropertyDeclaration *)property {
    [_propertyDeclarations addObject:property];
}

- (void)addInstanceVariableDeclaration:(MPObjCInstanceVariableDeclaration *)ivar {
    [_instanceVariableDeclarations addObject:ivar];
}

- (NSString *) description {
    return [NSString stringWithFormat:@"[name:%@ superclass:%@ protocols:%@ properties:%@ imethods:%@ cmethods:%@ ivars:%@]",
            self.name,
            self.superClassName,
            self.conformedProtocols,
            self.propertyDeclarations,
            self.instanceMethodDeclarations,
            self.classMethodDeclarations,
            self.instanceVariableDeclarations];
}

@end


@interface MPObjCProtocolDeclaration () {
    NSMutableArray *_conformedProtocols;
    NSMutableArray *_classMethodDeclarations;
    NSMutableArray *_instanceMethodDeclarations;
    NSMutableArray *_propertyDeclarations;
    NSMutableArray *_constantDeclarations;
}
@end

@implementation MPObjCProtocolDeclaration

- (instancetype)init {
    NSAssert(false, @"Use -initWithName: instead.");
    return nil;
}

- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    
    if (self) {
        _name = name;
        _conformedProtocols = [NSMutableArray new];
        _classMethodDeclarations = [NSMutableArray new];
        _instanceMethodDeclarations = [NSMutableArray new];
        _propertyDeclarations = [NSMutableArray new];
    }
    
    return self;
}

- (void)addConformedProtocol:(NSString *)superProtocol {
    [_conformedProtocols addObject:superProtocol];
}

- (void)addClassMethodDeclaration:(MPObjCClassMethodDeclaration *)methodDec {
    [_classMethodDeclarations addObject:methodDec];
}

- (void)addInstanceMethodDeclaration:(MPObjCInstanceMethodDeclaration *)methodDec {
    [_instanceMethodDeclarations addObject:methodDec];
}

- (void)addConstantDeclaration:(MPObjCConstantDeclaration *)constDec {
    [_constantDeclarations addObject:constDec];
}

- (void)addPropertyDeclaration:(MPObjCPropertyDeclaration *)propDec {
    [_propertyDeclarations addObject:propDec];
}

- (NSArray *)conformedProtocols {
    return _conformedProtocols.copy;
}

- (NSArray *)classMethodDeclarations {
    return _classMethodDeclarations.copy;
}

- (NSArray *)instanceMethodDeclarations {
    return _instanceMethodDeclarations.copy;
}

- (NSArray *)propertyDeclarations {
    return _propertyDeclarations.copy;
}

- (NSArray *)constantDeclarations {
    return _constantDeclarations.copy;
}

- (NSString *)description {
    return [NSString stringWithFormat:
            @"[name:%@ conformedProtocols:%@ instanceMethods:%@ classMethods:%@ properties:%@]",
            self.name,
            self.conformedProtocols,
            self.instanceMethodDeclarations,
            self.classMethodDeclarations,
            self.propertyDeclarations];
}

@end


@implementation MPObjCPropertyDeclaration

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

- (NSString *)description {
    return [NSString stringWithFormat:@"[name:%@ type:%@]", self.name, self.type];
}

@end


@implementation MPObjCInstanceVariableDeclaration

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

@interface MPObjCMethodDeclaration () {
    NSMutableArray *_parameters;
}
@end

@implementation MPObjCMethodDeclaration

- (instancetype)init {
    NSAssert(false, @"Use -initWithSelector:returnType: instead");
    return nil;
}

- (instancetype)initWithSelector:(NSString *)selector returnType:(NSString *)returnType {
    self = [super init];
    
    if (self) {
        _selector = selector;
        _returnType = returnType;
        
        _parameters = [NSMutableArray new];
    }
    
    return self;
}

- (void)addParameter:(MPObjCMethodParameter *)param {
    [_parameters addObject:param];
}

- (NSArray *)parameters {
    return _parameters;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[selector:%@ returnType:%@ parameters:%@]",
            self.selector, self.returnType, self.parameters];
}

@end

@implementation MPObjCInstanceMethodDeclaration
@end

@implementation MPObjCClassMethodDeclaration
@end


@implementation MPObjCMethodParameter

- (instancetype)init {
    NSAssert(false, @"Use -initWithName:type:selectorComponent: instead");
    return nil;
}

- (instancetype)initWithName:(NSString *)name type:(NSString *)type selectorComponent:(NSString *)selectorComponent {
    self = [super init];
    
    if (self) {
        _name = name;
        _type = type;
        _selectorComponent = selectorComponent;
    }
    
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[name:%@ type:%@ selectorComponent:%@]",
            self.name, self.type, self.selectorComponent];
}

@end