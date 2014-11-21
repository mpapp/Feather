//
//  ABRecord+ABRecord_MPExtensions.m
//  Feather
//
//  Created by Matias Piipari on 17/11/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import "ABRecord+MPExtensions.h"

@implementation ABRecord (MPExtensions)

- (NSString *)fullName {
    NSString *firstName, *lastName;
    
    firstName = [self valueForProperty:kABFirstNameProperty];
    lastName = [self valueForProperty:kABLastNameProperty];
    
    if (firstName && lastName)
        return [NSString stringWithFormat:@"%@ %@", firstName, lastName];
    else if (firstName)
        return firstName;
    else if (lastName)
        return lastName;
    
    NSString *orgName = [self valueForProperty:kABOrganizationProperty];
    
    if (orgName != nil)
        return orgName;
    
    return nil;
}

- (NSString *)lastName {
    return [self valueForProperty:kABLastNameProperty];
}

- (NSString *)affiliation {
    return [self valueForProperty:kABOrganizationProperty];
}

- (NSString *)identifier {
    return [self valueForProperty:kABUIDProperty];
}

- (NSImage *)avatarImage {
    if ([self respondsToSelector:@selector(imageData)]) {
        NSData * imageData = [self performSelector:@selector(imageData)];
        
        if (imageData)
            return [[NSImage alloc] initWithData:imageData];
    }
    
    // else
    return nil;
}

@end