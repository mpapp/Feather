//
//  MPException.h
//  Feather
//
//  Created by Matias Piipari on 19/12/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPException : NSException

@end

@interface MPUnexpectedSelectorException : MPException
- (instancetype)initWithSelector:(SEL)sel;
+ (id)exceptionWithSelector:(SEL)sel;
@end

@interface MPMethodIsPrivateException : MPUnexpectedSelectorException
@end

@interface MPInitIsPrivateException : MPUnexpectedSelectorException
@end

@interface MPIllegalStateException : MPException
- (instancetype)initWithReason:(NSString *)reason;
@end

@interface MPAbstractMethodException : MPException
- (instancetype)initWithSelector:(SEL)sel;
+ (id)exceptionWithSelector:(SEL)sel;
@end

@interface MPUnexpectedTypeException : MPException
- (instancetype)initWithTypeString:(NSString *)typeStr;
@end

@interface MPUnexpectedStateExpection : MPException
- (instancetype)initWithReason:(NSString *)reason;
@end

@interface MPReadonlyCachedPropertyException : MPException
- (instancetype)initWithPropertyKey:(NSString *)propertyKey ofClass:(Class)cls;
@end

@interface MPAbstractClassException : MPException
- (instancetype)initWithClass:(Class)cls;
@end