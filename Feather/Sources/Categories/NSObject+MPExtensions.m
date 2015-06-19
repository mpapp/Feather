"//
//  NSObject+Feather.m
//  Feather
//
//  Created by Matias Piipari on 08/12/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "NSObject+MPExtensions.h"
#import "NSArray+MPExtensions.h"
#import "NSSet+MPExtensions.h"
#import "NSString+MPExtensions.h"

#import <CouchbaseLite/CouchbaseLite.h>
#import <CouchbaseLite/MYDynamicObject.h>

#import <objc/runtime.h>

#import <DiffMatchPatch/DiffMatchPatch.h>

@implementation NSObject (Feather)

// Adapted from http://cocoawithlove.com/2010/01/getting-subclasses-of-objective-c-class.html

+ (NSArray *)subclasses {
    @synchronized (self) {
        return [self _subclasses];
    }
}

+ (NSArray *)_subclasses {
    // retrieve the list of subclasses from a cache.
    NSArray *subclasses = objc_getAssociatedObject(self, "subclasses");
    if (subclasses)
        return subclasses;
    
    int numClasses = objc_getClassList(NULL, 0);
    Class *classes = NULL;
    
    size_t classPointerSize = sizeof(Class);
    classes = (Class *)malloc(classPointerSize * (numClasses + 1));
    numClasses = objc_getClassList(classes, numClasses);
    
    NSMutableArray *result = [NSMutableArray array];
    for (NSInteger i = 0; i < numClasses; i++) {
        Class superClass = classes[i];
        NSString *superClassName = NSStringFromClass(superClass);
        
        // skip the KVO induced dynamically created subclasses.
        if ([superClassName hasPrefix:@"NSKVONotifying"])
            continue;
        
        do {
            superClass = class_getSuperclass(superClass);
        } while (superClass && superClass != self);
        
        if (superClass == nil) {
            continue;
        }
        
        [result addObject:classes[i]];
    }
    
    free(classes);
    
    // cache the list of subclasses.
    objc_setAssociatedObject(self, "subclasses", result.copy, OBJC_ASSOCIATION_RETAIN);
    
    return result;
}

+ (NSArray *)descendingClasses {
    NSMutableArray *descendents = [NSMutableArray new];
    [descendents addObjectsFromArray:self.subclasses];
    
    Class cls = self;
    
    // collate all subclasses of the class
    NSMutableSet *subclassSet = [NSMutableSet setWithCapacity:20];
    NSMutableArray *subclasses = [cls.subclasses mutableCopy];
    
    NSLog(@"Subclasses of %@: %@", NSStringFromClass(cls), subclasses);
    
    [subclassSet addObject:cls];
    [subclassSet addObjectsFromArray:subclasses];
    
    while (subclasses.count > 0)
    {
        Class subcls = [subclasses firstObject];
        [subclassSet addObjectsFromArray:subcls.subclasses];
        [subclasses removeObject:subcls];
    }
    
    return [[subclassSet mapObjectsUsingBlock:^id(Class class) {
        return NSStringFromClass(class);
    }] allObjects];
}

+ (NSArray *)classesMatchingPattern:(BOOL(^)(Class cls))patternBlock
{
    unsigned int classCount = 0;
    NSMutableArray *classArray = [NSMutableArray arrayWithCapacity:classCount];
    
    Class *classes = objc_copyClassList(&classCount);
    
    for (NSUInteger i = 0; i < classCount; i++)
    {
        Class cls = classes[i];
        if (patternBlock(cls)) [classArray addObject:cls];
    }
    
    free(classes);
    
    return [classArray copy];
}

+ (BOOL)propertyWithKeyIsReadWrite:(NSString *)key
{
    objc_property_t prop = class_getProperty(self, [key UTF8String]);
    if (!prop) return NO;
    
    const char attribs = *property_getAttributes(prop);
    if (!attribs) return NO;
    
    // R = readonly
    return ![[[NSString alloc] initWithUTF8String:&attribs] containsSubstring:@"R"];
}

+ (Class)commonAncestorForClass:(Class)a andClass:(Class)b
{
    if (a == b) return a;
    if (!a) return nil;
    if (!b) return nil;
    
    // check if a is subclass of b
    Class parent = a;
    while ((parent = class_getSuperclass(parent)) != nil && parent != b);
    
    // don't return NSObject yet before trying to see if b is a subclass of a
    if (parent && parent != [NSObject class])
        return parent;
    
    // check if b is subclass of a
    Class sourceParent = b;
    while ((sourceParent = class_getSuperclass(sourceParent)) != nil && a != sourceParent);
    
    if (sourceParent) return sourceParent;
    
    // FIXME: go back recursively more effectively.
    Class foundClass = [self commonAncestorForClass:class_getSuperclass(a) andClass:b];
    if (foundClass) return foundClass;
    
    return [self commonAncestorForClass:class_getSuperclass(b) andClass:a];
}

+ (NSDictionary *)propertiesOfSubclassesForClass:(Class)class matching:(BOOL(^)(Class cls, NSString *key))patternBlock
{
    NSArray *classes = [[class.subclasses mapObjectsUsingBlock:^id(Class cls, NSUInteger idx) {
        return NSStringFromClass(cls);
    }] arrayByAddingObject:NSStringFromClass(class)];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:classes.count];
    
    for (NSString *moClassName in classes)
    {
        Class moClass = NSClassFromString(moClassName);
        
        NSSet *readWritePropertyNamesMatchingPattern =
        [[moClass propertyKeys] filteredSetUsingPredicate:
         [NSPredicate predicateWithBlock:^BOOL(NSString *propName, NSDictionary *bindings)
          {
              return patternBlock(moClass, propName);
          }]];
        
        dict[moClassName] = readWritePropertyNamesMatchingPattern;
    }
    
    return [dict copy];
}

+ (NSSet *)propertyKeys {
    @synchronized (self) {
        return [self _propertyKeys];
    }
}

// Adapted from CouchDynamicObject -propertyNames
+ (NSSet *)_propertyKeys
{
    NSSet *propertyKeys = objc_getAssociatedObject(self, "propertyKeys");
    if (propertyKeys)
        return propertyKeys;
    
    if (self == [NSObject class])
        return [NSSet set];
    
    NSMutableSet* propertyNames = [NSMutableSet set];
    
    unsigned int propertyCount = 0;
    objc_property_t* propertiesExcludingSuperclass = class_copyPropertyList(self, &propertyCount);
    
    if (propertiesExcludingSuperclass) {
        objc_property_t* propertyPtr = propertiesExcludingSuperclass;
        while (*propertyPtr)
            [propertyNames addObject:@(property_getName(*propertyPtr++))];
        free(propertiesExcludingSuperclass);
    }
    [propertyNames unionSet:[[self superclass] propertyKeys]];
    
    objc_setAssociatedObject(self, "propertyKeys", propertyNames, OBJC_ASSOCIATION_RETAIN);
    
    return propertyNames;
}

- (void)matchingValueForKey:(NSString *)key value:(void(^)(const BOOL valueMatches, const id value))valueBlock
{
    valueBlock(YES, [self valueForKey:key]);
}

#pragma mark -

// From MYUtilities MYDynamicObject
// Look up the encoded type of a property, and whether it's readwrite / readonly
+ (Class)classOfProperty:(NSString *)propertyName
{
    Class declaredInClass;
    const char* propertyType;
    if (!MYGetPropertyInfo(self, propertyName, NO, &declaredInClass, &propertyType))
        return Nil;
    return MYClassFromType(propertyType);
}

- (id)performNonLeakingSelector:(SEL)selector
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [self performSelector:selector];
#pragma clang diagnostic pop
}

- (id)performNonLeakingSelector:(SEL)selector withObject:(id)object
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [self performSelector:selector withObject:object];
#pragma clang diagnostic pop
}

#pragma mark -

+ (void)performInQueue:(dispatch_queue_t)queue
            afterDelay:(NSTimeInterval)delay
                 block:(void (^)(void))block
{
    
    int64_t delta = (int64_t)(1.0e9 * delay);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delta), queue, block);
    
}

+ (void)performInMainQueueAfterDelay:(NSTimeInterval)delay
                               block:(void (^)(void))block

{
    
    int64_t delta = (int64_t)(1.0e9 * delay);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delta), dispatch_get_main_queue(), block);
}

#pragma mark - Swizzling

+ (void)replaceInstanceMethodWithSelector:(SEL)selector implementationProvider:(MPMethodImplementationProvider)swizzler
{
    Method origMethod = class_getInstanceMethod(self, selector);
    [self replaceMethodImplementation:origMethod withSelector:selector implementationProvider:swizzler];
}

+ (void)replaceInstanceMethodWithSelector:(SEL)selector implementationBlockProvider:(MPMethodImplementationBlockProvider)swizzler
{
    Method origMethod = class_getInstanceMethod(self, selector);
    [self replaceMethodImplementation:origMethod withSelector:selector implementationBlockProvider:swizzler];
}

+ (void)replaceClassMethodWithSelector:(SEL)selector implementationProvider:(MPMethodImplementationProvider)swizzler;
{
    Method origMethod = class_getClassMethod(self, selector);
    [self replaceMethodImplementation:origMethod withSelector:selector implementationProvider:swizzler];
}

+ (void)replaceClassMethodWithSelector:(SEL)selector implementationBlockProvider:(MPMethodImplementationBlockProvider)swizzler;
{
    Method origMethod = class_getClassMethod(self, selector);
    [self replaceMethodImplementation:origMethod withSelector:selector implementationBlockProvider:swizzler];
}

+ (void)replaceMethodImplementation:(Method)origMethod
                       withSelector:(SEL)selector
             implementationProvider:(MPMethodImplementationProvider)swizzler
{
    assert(origMethod);
    
    const char *typeEncoding = method_getTypeEncoding(origMethod);
    
    IMP origImpl = method_getImplementation(origMethod);
    IMP newImpl = swizzler(origImpl);
    
    if (!class_addMethod(self, selector, newImpl, typeEncoding))
    {
        BOOL replacementSuccessful = class_replaceMethod(self, selector, newImpl, typeEncoding);
        assert(replacementSuccessful);
    }
}

+ (void)replaceMethodImplementation:(Method)origMethod
                       withSelector:(SEL)selector
        implementationBlockProvider:(MPMethodImplementationBlockProvider)swizzler
{
    assert(origMethod);
    
    const char *typeEncoding = method_getTypeEncoding(origMethod);
    
    IMP origImpl = method_getImplementation(origMethod);
    IMP newImpl = imp_implementationWithBlock(swizzler(origImpl));
    
    if (!class_addMethod(self, selector, newImpl, typeEncoding))
    {
        class_replaceMethod(self, selector, newImpl, typeEncoding);
    }
}

+ (void)runUntilDone:(void (^)(dispatch_block_t))block
{
    __block BOOL done = NO;
    block(^()
          {
              done = YES;
          });
    while (!done)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

+ (void)runUntilDone:(void (^)(dispatch_block_t))block withTimeout:(NSTimeInterval)timeout timeoutBlock:(void (^)(void))timeoutBlock
{
    __block BOOL done = NO;
    block(^()
          {
              done = YES;
          });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, timeout * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if (!done)
        {
            timeoutBlock();
            done=YES;
        }
    });
    
    while (!done)
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

@end


dispatch_queue_t mp_dispatch_queue_create(NSString *label, NSUInteger queueSpecificToken, dispatch_queue_attr_t attr)
{
    dispatch_queue_t q = dispatch_queue_create([label UTF8String], attr);
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000 || MAC_OS_X_VERSION_MIN_REQUIRED >= 1080
	const void * key = (__bridge const void *)q;
#else
	const void * key = (const void *)q;
#endif
	
    // no token is set if it were 0
    if (queueSpecificToken)
        dispatch_queue_set_specific(q,
                                    key,
                                    (void *)queueSpecificToken, NULL);
    
    return q;
}

void mp_dispatch_sync(dispatch_queue_t q, NSUInteger queueSpecificToken, dispatch_block_t block)
{
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000 || MAC_OS_X_VERSION_MIN_REQUIRED >= 1080
	const void * key = (__bridge const void *)q;
#else
	const void * key = (const void *)q;
#endif
    
    const NSUInteger token = (const NSUInteger)dispatch_get_specific(key);
    
    if (token == queueSpecificToken)
        block();
    else
        dispatch_sync(q, block);
}

void mp_dispatch_async(dispatch_queue_t q, NSUInteger queueSpecificToken, dispatch_block_t block)
{
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000 || MAC_OS_X_VERSION_MIN_REQUIRED >= 1080
	const void * key = (__bridge const void *)q;
#else
	const void * key = (const void *)q;
#endif
    
    const NSUInteger token = (const NSUInteger)dispatch_get_specific(key);
    
    if (token == queueSpecificToken)
        block();
    else
        dispatch_async(q, block);
}

#pragma mark - Charles Parnot's object diffing


@implementation NSObject (FDPropertyListDiff)

- (BOOL)isPlist
{
    return [self isKindOfClass:[NSString class]] | [self isKindOfClass:[NSArray class]] | [self isKindOfClass:[NSDictionary class]] | [self isKindOfClass:[NSNumber class]];
}

#define MAX_CHARS 60

- (NSString *)diffDescription
{
    if ([self isKindOfClass:[NSDictionary class]] || [self isKindOfClass:[NSArray class]])
    {
        NSString *shortDescription = [self description];
        if ([shortDescription length] > MAX_CHARS)
            shortDescription = [[shortDescription substringToIndex:MAX_CHARS] stringByAppendingString:@"..."];
        return [NSString stringWithFormat:@"%@ entries: %@", @([(id)self count]), shortDescription];
    }
    
    else if ([self isKindOfClass:[NSData class]])
    {
        NSString *shortDescription = [self description];
        if ([shortDescription length] > MAX_CHARS)
            shortDescription = [[shortDescription substringToIndex:MAX_CHARS] stringByAppendingString:@"..."];
        return [NSString stringWithFormat:@"%@ bytes: %@", @([(id)self length]), shortDescription];
    }
    
    else if ([self isKindOfClass:[NSString class]])
    {
        return [NSString stringWithFormat:@"%@ characters: %@", @([(id)self length]), [self description]];
    }
    
    else
        return [self description];
}

- (void)appendToString:(NSMutableString *)diff
        diffWithObject:(id)otherObject
            identifier:(id)identifier
          excludedKeys:(NSSet *)excludedKeys
{
    id object1 = self;
    id object2 = otherObject;
    BOOL bothArrays  = [object1 isKindOfClass:[NSArray class]]      && [object2 isKindOfClass:[NSArray class]];
    BOOL bothSets    = [object1 isKindOfClass:[NSSet class]]        && [object2 isKindOfClass:[NSSet class]];
    BOOL bothDics    = [object1 isKindOfClass:[NSDictionary class]] && [object2 isKindOfClass:[NSDictionary class]];
    
    if (bothArrays)
    {
        NSArray *array1 = object1;
        NSArray *array2 = object2;
        if ([array1 count] != [array2 count])
        {
            [diff appendFormat:@"@@ %@.@count @@\n", identifier];
            [diff appendFormat:@"- %@ objects\n", @([array1 count])];
            [diff appendFormat:@"+ %@ objects\n", @([array2 count])];
            return;
        }
        for (NSUInteger index = 0; index < [array1 count]; index++)
        {
            id arrayObject1 = array1[index];
            id arrayObject2 = array2[index];
            [arrayObject1 appendToString:diff diffWithObject:arrayObject2 identifier:[NSString stringWithFormat:@"%@[%@]", identifier, @(index)] excludedKeys:excludedKeys];
        }
    }
    
    else if (bothSets)
    {
        NSSet *set1 = object1;
        NSSet *set2 = object2;
        if ([set1 count] != [set2 count])
        {
            [diff appendFormat:@"@@ %@.@count @@\n", identifier];
            [diff appendFormat:@"- %@ objects\n", @([set1 count])];
            [diff appendFormat:@"+ %@ objects\n", @([set2 count])];
            return;
        }
        if (![set1 isEqualToSet:set2])
        {
            NSMutableSet *onlySet1 = [NSMutableSet setWithSet:set1];
            NSMutableSet *onlySet2 = [NSMutableSet setWithSet:set2];
            [onlySet1 minusSet:set2];
            [onlySet2 minusSet:set1];
            NSArray *array1 = [onlySet1 allObjects];
            NSArray *array2 = [onlySet2 allObjects];
            [array1 appendToString:diff diffWithObject:array2 identifier:[NSString stringWithFormat:@"%@.allObjects", identifier] excludedKeys:excludedKeys];
        }
    }
    
    else if (bothDics)
    {
        // distinct keys and shared keys
        NSDictionary *dic1 = object1;
        NSDictionary *dic2 = object2;
        NSSet *keys1 = [NSSet setWithArray:[dic1 allKeys]];
        NSSet *keys2 = [NSSet setWithArray:[dic2 allKeys]];
        NSMutableSet *distinctKeys1 = nil;
        NSMutableSet *distinctKeys2 = nil;
        NSMutableSet *sharedKeys = [NSMutableSet setWithSet:keys1];
        [sharedKeys minusSet:excludedKeys];
        if (![keys1 isEqualToSet:keys2])
        {
            distinctKeys1 = [NSMutableSet setWithSet:keys1];
            [distinctKeys1 minusSet:excludedKeys];
            [distinctKeys1 minusSet:keys2];
            distinctKeys2 = [NSMutableSet setWithSet:keys2];
            [distinctKeys2 minusSet:excludedKeys];
            [distinctKeys2 minusSet:keys1];
            [sharedKeys minusSet:distinctKeys1];
            [sharedKeys minusSet:distinctKeys2];
        }
        
        // distinct keys
        if ([distinctKeys1 count] > 0 || [distinctKeys2 count] > 0)
        {
            for (NSString *key in distinctKeys1)
            {
                [diff appendFormat:@"@@ %@.%@ @@\n", identifier, key];
                [diff appendFormat:@"- %@\n", [dic1[key] diffDescription]];
            }
            for (NSString *key in distinctKeys2)
            {
                [diff appendFormat:@"@@ %@.%@ @@\n", identifier, key];
                [diff appendFormat:@"+ %@\n", [dic2[key] diffDescription]];
            }
        }
        
        // shared keys
        for (NSString *key in sharedKeys)
        {
            id dicObject1 = dic1[key];
            id dicObject2 = dic2[key];
            [dicObject1 appendToString:diff diffWithObject:dicObject2 identifier:[NSString stringWithFormat:@"%@.%@", identifier, key] excludedKeys:excludedKeys];
        }
    }
    
    else if (![object1 isEqual:object2])
    {
        [diff appendFormat:@"@@ %@ @@\n", identifier];
        [diff appendFormat:@"- [%@] %@\n", NSStringFromClass([object1 class]), [object1 diffDescription]];
        [diff appendFormat:@"+ [%@] %@\n", NSStringFromClass([object2 class]), [object2 diffDescription]];
    }
}

- (NSString *)differencesWithPropertyListEncodable:(id)otherPlist
                                        identifier:(NSString *)identifier
                                      excludedKeys:(NSSet *)excludedKeys
{
    NSMutableString *diff = [NSMutableString string];
    [self appendToString:diff diffWithObject:otherPlist identifier:identifier excludedKeys:excludedKeys];
    return [NSString stringWithString:diff];
}

@end

@implementation NSString (NSStringDiff)
- (NSString *)prettyHTMLDiffWithString:(NSString *)otherString
{
#if TARGET_OS_IPHONE
    // iOS device
#elif TARGET_IPHONE_SIMULATOR
    // iOS Simulator
#elif TARGET_OS_MAC
    // Other kinds of Mac OS
    DiffMatchPatch *diffObject = [[DiffMatchPatch alloc] init];
    NSMutableArray *diffs = [diffObject diff_mainOfOldString:self andNewString:otherString];
    return [diffObject diff_prettyHtml:diffs];
#else
    // Unsupported platform
#endif
    return nil;
}
@end

