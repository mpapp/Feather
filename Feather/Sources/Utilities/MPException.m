//
//  MPException.m
//  Manuscripts
//
//  Created by Matias Piipari on 19/12/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
//

#import "MPException.h"

@implementation MPException

@end

@implementation MPUnexpectedSelectorException

- (instancetype)init
{
    @throw [[MPUnexpectedSelectorException alloc] initWithSelector:_cmd];
    return nil;
}

- (instancetype)initWithSelector:(SEL)sel
{
    return [super initWithName:NSStringFromClass([self class])
                        reason:[NSString stringWithFormat:@"Don't call %@ on this kind of object.", NSStringFromSelector(sel)]
                      userInfo:nil];
}

+ (id)exceptionWithSelector:(SEL)sel { return [[self alloc] initWithSelector:sel]; }

@end

@implementation MPInitIsPrivateException
@end

@implementation MPAbstractMethodException

- (instancetype)init
{
    @throw [[MPUnexpectedSelectorException alloc] initWithSelector:_cmd];
    return nil;
}

- (instancetype)initWithName:(NSString *)aName reason:(NSString *)aReason userInfo:(NSDictionary *)aUserInfo
{
    @throw [[MPUnexpectedSelectorException alloc] initWithSelector:_cmd];
    return nil;
}

- (instancetype)initWithSelector:(SEL)sel
{
    return [super initWithName:NSStringFromClass([self class])
                        reason:[NSString stringWithFormat:@"Subclass needs to implement %@.",
                                NSStringFromSelector(sel)] userInfo:nil];
}

+ (id)exceptionWithSelector:(SEL)sel { return [[self alloc] initWithSelector:sel]; }

@end

@implementation MPUnexpectedTypeException

- (instancetype)init
{
    @throw [[MPUnexpectedSelectorException alloc] initWithSelector:_cmd];
}

- (instancetype)initWithTypeString:(NSString *)typeStr
{
    return [self initWithName:NSStringFromClass([self class]) reason:typeStr userInfo:nil];
}

@end

@implementation MPUnexpectedStateExpection

- (instancetype)initWithReason:(NSString *)reason
{
    return [self initWithName:NSStringFromClass([self class]) reason:reason userInfo:nil];
}

@end

@implementation MPReadonlyCachedPropertyException

- (instancetype)initWithPropertyKey:(NSString *)propertyKey ofClass:(Class)class
{
    if (self = [super initWithName:NSStringFromClass([self class])
                            reason:[NSString stringWithFormat:@"Property '%@' should be readwrite.", propertyKey]
                          userInfo:nil])
    { }
    
    return self;
}

@end

@implementation MPAbstractClassException

- (instancetype)initWithClass:(Class)cls
{
    if (self = [super initWithName:NSStringFromClass([self class])
                            reason:[NSString stringWithFormat:
                                    @"Objects with class %@ should not be instantiated.", cls]
                          userInfo:nil])
    { }
    
    return self;
}

@end