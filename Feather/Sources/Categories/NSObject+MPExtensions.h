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

#if defined __cplusplus
extern "C" {
#endif
    
    /** Create a dispatch queue with a given queue specific token. */
    dispatch_queue_t mp_dispatch_queue_create(NSString *label, NSUInteger queueSpecificToken, dispatch_queue_attr_t attr);
    
    /** Dispatch asynchronously to queue q. If current queue is q, block is run, otherwise dispatch_sync'ed to q. */
    extern void mp_dispatch_sync(dispatch_queue_t q, NSUInteger queueSpecificToken, dispatch_block_t block);
    
    /** Dispatch asynchronously to queue q. If current queue is q, block is run, otherwise dispatch_async'ed. */
    extern void mp_dispatch_async(dispatch_queue_t q, NSUInteger queueSpecificToken, dispatch_block_t block);
    
#if defined __cplusplus
};
#endif