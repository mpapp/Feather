//
//  MPStringIndenter.h
//  Bindings
//
//  Created by Matias Piipari on 11/10/2014.
//  Copyright (c) 2014-2015 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPIndentedMutableString : NSObject <NSCopying>

@property (readonly) NSUInteger indentationSpaceCount;

- (instancetype)initWithIndentationSpaceCount:(NSUInteger)indentationSpaceCount;

- (void)appendString:(NSString *)string;
- (void)appendLine:(NSString *)string;
//- (void)appendFormat:(NSString *)format, ... NS_REQUIRES_NIL_TERMINATION;

- (void)indent:(void(^)())block;

@property (readonly, copy) NSString *stringRepresentation;

@end
