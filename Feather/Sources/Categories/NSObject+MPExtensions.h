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

NS_INLINE BOOL MPOptionIsOn(NSUInteger flags, NSUInteger flag)
{
    if (flag == 0)
        return YES;
    return ((flags & flag) == flag);
}

@interface NSObject (Feather)

+ (NSArray *)subclasses;

/** Subclasses of subclasses of ... of self */
+ (NSArray *)descendingClasses;

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

/**
 *  A method swizzling handler block: returns a new method implementation, receiving as its argument the original implementation (allows calling the original).
 *
 *  @param originalImplementation Handler receives
 *
 *  @return Returns the new method implementation which is used to replace the old. 
 */
typedef IMP (^MPMethodImplementationProvider)(IMP originalImplementation);

typedef id(^MPMethodImplementationBlockProvider)(IMP originalImplementation);

/**
 *  Replace instance method with specified selector with an implementation returned by the provided implementation provider block.
 *
 *  @param selector Selector of the instance method to be replaced.
 *  @param swizzler A block whose return value is a new implementation
 */
+ (void)replaceInstanceMethodWithSelector:(SEL)selector implementationProvider:(MPMethodImplementationProvider)swizzler;

+ (void)replaceInstanceMethodWithSelector:(SEL)selector implementationBlockProvider:(MPMethodImplementationBlockProvider)swizzler;

/**
 *  Replace class method with specified selector with an implementation returned by the provided implementation provider block.
 *
 *  @param selector Selector of the instance method to be replaced.
 *  @param swizzler A block whose return value is a new implementation
 */
+ (void)replaceClassMethodWithSelector:(SEL)selector implementationProvider:(MPMethodImplementationProvider)swizzler;

+ (void)replaceClassMethodWithSelector:(SEL)selector implementationBlockProvider:(MPMethodImplementationBlockProvider)swizzler;

/**
 * Spins the current runloop until onceDoneBlock() is called.
 * @warning The run loop sources will be polled every 0.05s - this is not intended for production code, only for testing!
 *
 *  @param block a block containing code that should be executed once run loop spinning should end.
 */
+ (void)runUntilDone:(void (^)(dispatch_block_t onceDoneBlock))block;

/**
 * Spins the current runloop until onceDoneBlock() is called, or a timeout period is exceeded while waiting.
 * @warning The run loop sources will be polled every 0.05s - this is not intended for production code, only for testing!
 *
 *  @param block a block containing code that should be executed once run loop spinning should end.
 *  @param timeout maximum time to wait for completion
 *  @param timeoutBlock block to execute in the event of a timeout
 */
+ (void)runUntilDone:(void (^)(dispatch_block_t))block withTimeout:(NSTimeInterval)timeout timeoutBlock:(void (^)(void))timeoutBlock;


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



@interface NSObject (FDPropertyListDiff)

/**
 *  A string represention of differences between self and another object. Both self and the compared to object must be plist-encodable.
 *
 *  @param otherPlist   Object to compare to.
 *  @param identifier   An identifier included for all diff entries in the output string.
 *  @param excludedKeys Keys to exclude for dictionary comparisons, and recursively for all key path components in all the possible key paths in the object tree (if nil or empty, none excluded).
 *
 *  @return A patch-like formatted string representing all differences. If there are no differences, string is empty.
 */
- (NSString *)differencesWithPropertyListEncodable:(id)otherPlist
                                        identifier:(NSString *)identifier
                                      excludedKeys:(NSSet *)excludedKeys;

@end