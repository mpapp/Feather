//
//  Created by Matias Piipari on 18/01/2013.
//  Copyright (c) 2013 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MPErrorNotificationObserver;

@interface NSNotificationCenter (ManuscriptsError)
- (void)postErrorNotification:(NSError *)error;
- (void)addErrorObserver:(id<MPErrorNotificationObserver>)errorObserver;
@end

@protocol MPErrorNotificationObserver <NSObject>
- (void)errorDidOccur:(NSNotification *)notification;
@end