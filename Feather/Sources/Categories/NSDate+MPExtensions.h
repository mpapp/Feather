//
//  NSDate+MPExtensions.h
//  Feather
//
//  Created by Matias Piipari on 06/05/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Foundation;

@interface NSDate (MPExtensions)

- (NSString *)relativeDateString;

//
// Simple debug instrumentation
//

/**
 `NSLog()` given message and return current time interval since `NSDate`'s reference date, to be used as an argument to consecutive `logDurationSince:message:` calls.
 */
+ (NSTimeInterval)startMeasuring:(NSString *)message;

/** Log how long it has been since given measurement start time. */
+ (NSTimeInterval)logDurationSince:(NSTimeInterval)startTime message:(NSString *)message;

@end
