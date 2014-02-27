//
//  Created by Matias Piipari on 18/01/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MPErrorNotificationObserver;

@interface NSNotificationCenter (FeatherError)
- (void)postErrorNotification:(NSError *)error __attribute__((nonnull));
- (void)addErrorObserver:(id<MPErrorNotificationObserver>)errorObserver;
@end

@protocol MPErrorNotificationObserver <NSObject>
- (void)errorDidOccur:(NSNotification *)notification;
@end