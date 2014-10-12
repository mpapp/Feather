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

