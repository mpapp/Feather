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

@end

