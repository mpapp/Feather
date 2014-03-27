//
//  NSTask+MPExtensions.h
//  Feather
//
//  Created by Markus on 23.4.2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef void (^MPTaskTerminationHandler)(NSTask *task);


@interface NSTask (MPExtensions)

+ (NSTask *)runCommand:(NSString *)command
         withArguments:(NSArray *)arguments
       atDirectoryPath:(NSString *)path
    terminationHandler:(MPTaskTerminationHandler)terminationHandler;

- (NSString *)commandLine;

@end
