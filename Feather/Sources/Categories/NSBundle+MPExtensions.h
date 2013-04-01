//
//  NSBundle+Feather.h
//  Feather
//
//  Created by Matias Piipari on 17/11/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSBundle (Feather)

@property (readonly, copy) NSString *bundleNameString;
@property (readonly, copy) NSString *bundleVersionString;

/** Returns the main bundle for non-unit test targets, and the unit test bundle for the unit tests. */
+ (NSBundle *)appBundle;

+ (NSBundle *)XPCServiceBundleWithName:(NSString *)name;

@end
