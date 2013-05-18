//
//  MPIndexableMixin.h
//  Feather
//
//  Created by Matias Piipari on 08/05/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MPTitledProtocol.h"

@protocol MPIndexable <MPTitledProtocol, NSObject>
+ (NSArray *)indexablePropertyKeys;

@property (readwrite, strong) NSString *contents;

@end

@interface MPIndexableMixin : NSObject <MPIndexable>
@end
