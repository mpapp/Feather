//
//  MPExtensions.m
//  Feather
//
//  Created by Matias Piipari on 05/04/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import "NSUUID+MPExtensions.h"

@implementation NSUUID (MPExtensions)

- (unsigned long)unsignedLongValue
{
    static size_t unsignedLongSize = sizeof(unsigned long);
    static size_t uuidSize = sizeof(uuid_t);
    unsigned char *bytes = malloc(uuidSize);
    [self getUUIDBytes:bytes];
    
    unsigned long unsignedLongVal = 0;
    for (size_t i = unsignedLongSize - 1; i > 0; i--)
        unsignedLongVal = unsignedLongVal | (bytes[i] << (i << 3));
    
    free(bytes);
    
    return unsignedLongVal;
}

@end
