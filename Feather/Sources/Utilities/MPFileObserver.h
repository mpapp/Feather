//
//  MPFileObserver.h
//  Feather
//
//  Created by Matias Piipari on 15/07/2015.
//  Copyright (c) 2015 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^MPFileObservationReadAccessHandler)(NSError *subItemURL);
typedef void (^MPFileObservationChangeHandler)(NSURL *subItemURL);

@interface MPFileObserver : NSObject

- (instancetype)initWithFileURL:(NSURL *)fileURL subItemChangeHandler:(MPFileObservationChangeHandler)fileChangeHandler;

@end
