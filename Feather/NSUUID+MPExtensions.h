//
//  MPExtensions.h
//  Feather
//
//  Created by Matias Piipari on 05/04/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MPExtensions : NSUUID

/** Reduction of the UUID to an unsigned long value (first bytes). */
- (unsigned long)unsignedLongValue;

@end
