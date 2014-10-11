//
//  MPObjectiveCTokens.h
//  Bindings
//
//  Created by Matias Piipari on 11/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MPObjectiveCEnumConstant;

@interface MPObjectiveCEnumDeclaration : NSObject
@property (readonly) NSString *name;
@property (readwrite) NSString *backingType;

@property (readonly, copy) NSArray *enumConstants;

- (instancetype)initWithName:(NSString *)name;

- (void)addEnumConstant:(MPObjectiveCEnumConstant *)enumConstant;

@end

@interface MPObjectiveCEnumConstant : NSObject

@property (readonly, weak) MPObjectiveCEnumDeclaration *enumDeclaration;
@property (readonly) NSString *name;
@property (readwrite) NSNumber *value;

- (instancetype)initWithEnumDeclaration:(MPObjectiveCEnumDeclaration *)enumDeclaration
                                   name:(NSString *)name;
@end

