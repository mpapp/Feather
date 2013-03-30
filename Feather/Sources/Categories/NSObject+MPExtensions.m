//
//  NSObject+Manuscripts.m
//  Manuscripts
//
//  Created by Matias Piipari on 08/12/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
//

#import "NSObject+MPExtensions.h"
#import "NSArray+MPExtensions.h"
#import "NSString+MPExtensions.h"

#import <objc/runtime.h>

inline id MPNilToObject(id object, id defaultObject)
{
    return (object != nil) ? object : defaultObject;
}

@implementation NSObject (Manuscripts)

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
        
        [dict setObject:readWritePropertyNamesMatchingPattern forKey:moClassName];
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
    
    NSSet* cachedPropertyNames = [classToNames objectForKey:self];
    if (cachedPropertyNames)
        return cachedPropertyNames;
    
    NSMutableSet* propertyNames = [NSMutableSet set];
    
    unsigned int propertyCount = 0;
    objc_property_t* propertiesExcludingSuperclass = class_copyPropertyList(self, &propertyCount);
    
    if (propertiesExcludingSuperclass) {
        objc_property_t* propertyPtr = propertiesExcludingSuperclass;
        while (*propertyPtr)
            [propertyNames addObject:[NSString stringWithUTF8String:property_getName(*propertyPtr++)]];
        free(propertiesExcludingSuperclass);
    }
    [propertyNames unionSet:[[self superclass] propertyKeys]];
    [classToNames setObject: propertyNames forKey: (id)self];
    return propertyNames;
}

@end
