//
//  MPCountryList.h
//  Feather
//
//  Created by Matias Piipari on 28/04/2015.
//  Copyright (c) 2015 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPCountryList : NSObject

+ (NSArray *)countryNames;
+ (NSArray *)countryCodes;
+ (NSDictionary *)countryNamesByCode;
+ (NSDictionary *)countryCodesByName;

@end
