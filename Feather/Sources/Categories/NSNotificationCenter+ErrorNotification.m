//
//  Created by Matias Piipari on 18/01/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "NSNotificationCenter+ErrorNotification.h"

@implementation NSNotificationCenter (FeatherError)

NSString *const MPErrorNotification = @"MPErrorNotification";

- (void)addErrorObserver:(id<MPErrorNotificationObserver>)errorObserver
{
    [self addObserver:errorObserver selector:@selector(errorDidOccur:) name:MPErrorNotification object:nil];
}

- (void)postErrorNotification:(NSError *)error
{
    assert(error);
    NSLog(@"ERROR: %@", error);
    [self postNotificationName:MPErrorNotification object:error];
}

@end