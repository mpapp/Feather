//
//  NSObject+Manuscripts.h
//  Manuscripts
//
//  Created by Matias Piipari on 08/12/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>


extern inline id MPNilToObject(id object, id defaultObject);


@interface NSObject (Manuscripts)

+ (NSArray *)subclassesForClass:(Class)class;

+ (BOOL)propertyWithKeyIsReadWrite:(NSString *)key;

+ (Class)commonAncestorForClass:(Class)A andClass:(Class)B;

+ (NSDictionary *)propertiesOfSubclassesForClass:(Class)class matching:(BOOL(^)(Class cls, NSString *key))patternBlock;
+ (NSSet *)propertyKeys;

@end
