//
//  MPIndexableMixin.m
//  Feather
//
//  Created by Matias Piipari on 08/05/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPIndexableMixin.h"

@implementation MPIndexableMixin
@dynamic title, subtitle, desc, contents;

+ (NSArray *)indexablePropertyKeys {
    return @[ @"title", @"desc", @"contents" ];
}

@end
