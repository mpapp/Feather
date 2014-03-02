//
//  NSObject+Feather.h
//  Feather
//
//  Created by Matias Piipari on 08/12/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>


NS_INLINE id MPNilToObject(id object, id defaultObject)
{
    return (object != nil) ? object : defaultObject;
}

NS_INLINE id MPNilToNSNull(id object)
{
    return MPNilToObject(object, NSNull.null);
}


@interface NSObject (Feather)

+ (NSArray *)subclassesForClass:(Class)class;

+ (BOOL)propertyWithKeyIsReadWrite:(NSString *)key;

+ (Class)commonAncestorForClass:(Class)A andClass:(Class)B;

+ (NSDictionary *)propertiesOfSubclassesForClass:(Class)class matching:(BOOL(^)(Class cls, NSString *key))patternBlock;
+ (NSSet *)propertyKeys;

- (id)performNonLeakingSelector:(SEL)selector;
- (id)performNonLeakingSelector:(SEL)selector withObject:(id)object;

+ (Class)classOfProperty:(NSString *)propertyName;

+ (NSArray *)classesMatchingPattern:(BOOL(^)(Class cls))patternBlock;

/** -matchingValueForKey:value: defined also on NSArray: allows treating single and multiple selections in the same way. */
- (void)matchingValueForKey:(NSString *)key value:(void(^)(const BOOL valueMatches, const id value))valueBlock;

+ (void)performInQueue:(dispatch_queue_t)queue afterDelay:(NSTimeInterval)delay block:(void (^)(void))block;

+ (void)performInMainQueueAfterDelay:(NSTimeInterval)delay block:(void (^)(void))block;

@end
