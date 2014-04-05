//
//  NSObject+Feather.m
//  Feather
//
//  Created by Matias Piipari on 08/12/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "NSObject+MPExtensions.h"
#import "NSArray+MPExtensions.h"
#import "NSString+MPExtensions.h"

#import <CouchbaseLite/CouchbaseLite.h>
#import <CouchbaseLite/MYDynamicObject.h>
#import <objc/runtime.h>


@implementation NSObject (Feather)

// Adapted from http://cocoawithlove.com/2010/01/getting-subclasses-of-objective-c-class.html

+ (NSArray *)subclassesForClass:(Class)parentClass
{
    int numClasses = objc_getClassList(NULL, 0);
    Class *classes = NULL;
    
    size_t classPointerSize = sizeof(Class);
    classes = (Class *)malloc(classPointerSize * numClasses);
    numClasses = objc_getClassList(classes, numClasses);
    
    NSMutableArray *result = [NSMutableArray array];
    for (NSInteger i = 0; i < numClasses; i++)
    {
        Class superClass = classes[i];
        do
        {
            superClass = class_getSuperclass(superClass);
        } while(superClass && superClass != parentClass);
        
        if (superClass == nil)
        {
            continue;
        }
        
        [result addObject:classes[i]];
    }
    
    free(classes);
    
    return result;
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
    NSArray *classes = [[[class subclassesForClass:class] mapObjectsUsingBlock:^id(Class cls, NSUInteger idx) {
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


// Adapted from CouchDynamicObject -propertyNames
+ (NSSet *)propertyKeys
{
    static NSMutableDictionary* classToNames;
    if (!classToNames)
        classToNames = [[NSMutableDictionary alloc] init];
    
    if (self == [NSObject class]) return [NSSet set];
    
    NSSet* cachedPropertyNames = classToNames[self];
    if (cachedPropertyNames)
        return cachedPropertyNames;
    
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
    classToNames[(id)self] = propertyNames;
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
