//
//  MPModelFoundationTests.m
//  Feather
//
//  Created by Matias Piipari on 06/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPModelFoundationTests.h"
#import "Feather.h"
#import "MPFeatherTestClasses.h"

@implementation MPModelFoundationTests

- (void)testNotifications
{
    NSDictionary *notificationDict = [NSNotificationCenter managedObjectNotificationNameDictionary];
    
    STAssertTrue([notificationDict[@(MPChangeTypeAdd)][NSStringFromClass([MPMoreSpecificTestObject class])][@"did"] isEqualToString:@"didAddTestObject"],
                 @"The notification name for MPMoreSpecificTestObject is MPTestObject because \
                 there is a MPTestObjectsController but no MPMoreSpecificTestObjectsController.");
    
    STAssertTrue([notificationDict[@(MPChangeTypeUpdate)][NSStringFromClass([MPMoreSpecificTestObject class])][@"has"] isEqualToString:@"hasUpdatedTestObject"],
                 @"The notification name for MPMoreSpecificTestObject is MPTestObject because \
                 there is a MPTestObjectsController but no MPMoreSpecificTestObjectsController.");
}

@end
