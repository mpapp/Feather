//
//  ABRecord+ABRecord_MPExtensions.h
//  Feather
//
//  Created by Matias Piipari on 17/11/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import <AddressBook/AddressBook.h>

@interface ABRecord (MPExtensions)

@property (readonly) NSString *fullName;
@property (readonly) NSString *lastName;
@property (readonly) NSString *affiliation;
@property (readonly) NSString *identifier;
@property (readonly) NSImage *avatarImage;

@end
