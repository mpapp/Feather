//
//  NSTaskMPExtensions.m
//  Feather
//
//  Created by Markus on 23.4.2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//


#import "NSTask+MPExtensions.h"


@implementation NSTask (MPExtensions)

+ (NSTask *)runCommand:(NSString *)command
         withArguments:(NSArray *)arguments
       atDirectoryPath:(NSString *)path
    terminationHandler:(MPTaskTerminationHandler)terminationHandler
{
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = command;
    task.currentDirectoryPath = path;
    task.arguments = arguments;
    
    task.standardError = [NSPipe pipe];
    
    [task.standardError fileHandleForReading].readabilityHandler = ^(NSFileHandle *fh) {
        NSString *output = [[NSString alloc] initWithData:[fh availableData] encoding:NSUTF8StringEncoding];
        NSLog(@"[ERROR] %@", output);
    };
    
    task.standardOutput = [NSPipe pipe];
    
    [task.standardOutput fileHandleForReading].readabilityHandler = ^(NSFileHandle *fh) {
        NSString *output = [[NSString alloc] initWithData:[fh availableData] encoding:NSUTF8StringEncoding];
        NSLog(@"[INFO] %@", output);
    };
    
    task.terminationHandler = terminationHandler;
    
    [task launch];
    
    return task;
}

@end
