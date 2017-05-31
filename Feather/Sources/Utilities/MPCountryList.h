//
//  MPCountryList.h
//  Feather
//
//  Created by Matias Piipari on 28/04/2015.
//  Copyright (c) 2015 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPCountryList : NSObject

+ (nonnull NSArray<NSString *> *)countryNames;
+ (nonnull NSArray<NSString *> *)countryCodes;
+ (nonnull NSDictionary<NSString *, NSString *> *)countryNamesByCode;
+ (nonnull NSDictionary<NSString *, NSString *> *)countryCodesByName;

@end
