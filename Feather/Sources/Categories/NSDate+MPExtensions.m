//
//  NSDate+MPExtensions.m
//  Feather
//
//  Created by Matias Piipari on 06/05/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "NSDate+MPExtensions.h"

@implementation NSDate (MPExtensions)

- (NSString *)relativeDateString
{
    const int SECOND = 1;
    const int MINUTE = 60 * SECOND;
    const int HOUR = 60 * MINUTE;
    const int DAY = 24 * HOUR;
    const int MONTH = 30 * DAY;
    
    NSDate *now = [NSDate date];
    NSTimeInterval delta = [self timeIntervalSinceDate:now] * -1.0;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSUInteger units = (NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond);
    NSDateComponents *components = [calendar components:units fromDate:self toDate:now options:0];
    
    NSString *relativeString;
    
    if (delta < 0) {
        if (-delta < 1 * MINUTE) {
            relativeString = @"just now";
        } else if (-delta < 2 * MINUTE) {
            relativeString =  @"a minute from now";
            
        } else if (-delta < 45 * MINUTE) {
            relativeString = [NSString stringWithFormat:@"%lu minutes from now",components.minute];
            
        } else if (-delta < 90 * MINUTE) {
            relativeString = @"an hour from now";
            
        } else if (-delta < 24 * HOUR) {
            relativeString = [NSString stringWithFormat:@"%lu hours from now",components.hour];
            
        } else if (-delta < 48 * HOUR) {
            relativeString = @"yesterday";
            
        } else if (-delta < 30 * DAY) {
            relativeString = [NSString stringWithFormat:@"%lu days from now", components.day];
            
        } else if (-delta < 12 * MONTH) {
            relativeString = (components.month <= 1) ? @"one month from now" : [NSString stringWithFormat:@"%lu months from now",components.month];
            
        } else {
            relativeString = (components.year <= 1) ? @"one year from now" : [NSString stringWithFormat:@"%lu years from now",components.year];
            
        }
    } else if (delta < 1 * MINUTE) {
        if (delta < 5) {
            relativeString = @"just now";
        } else {
            relativeString = (components.second == 1) ? @"One second ago" : [NSString stringWithFormat:@"%lu seconds ago",components.second];
        }
        
    } else if (delta < 2 * MINUTE) {
        relativeString =  @"a minute ago";
        
    } else if (delta < 45 * MINUTE) {
        relativeString = [NSString stringWithFormat:@"%lu minutes ago",components.minute];
        
    } else if (delta < 90 * MINUTE) {
        relativeString = @"an hour ago";
        
    } else if (delta < 24 * HOUR) {
        relativeString = [NSString stringWithFormat:@"%lu hours ago",components.hour];
        
    } else if (delta < 48 * HOUR) {
        relativeString = @"yesterday";
        
    } else if (delta < 30 * DAY) {
        relativeString = [NSString stringWithFormat:@"%lu days ago",components.day];
        
    } else if (delta < 12 * MONTH) {
        relativeString = (components.month <= 1) ? @"one month ago" : [NSString stringWithFormat:@"%lu months ago",components.month];
        
    } else {
        relativeString = (components.year <= 1) ? @"one year ago" : [NSString stringWithFormat:@"%lu years ago",components.year];
        
    }
    
    return relativeString;
}

+ (NSTimeInterval)startMeasuring:(NSString *)message
{
    if (message) {
        NSLog(@"[Start measurement] %@", message);
    }
    return [NSDate timeIntervalSinceReferenceDate];
}

+ (NSTimeInterval)logDurationSince:(NSTimeInterval)startTime message:(NSString *)message
{
    NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate] - startTime;
    NSLog(@"[Note measurement] %@ took %@ seconds", message, @(duration));
    return duration;
}

@end
