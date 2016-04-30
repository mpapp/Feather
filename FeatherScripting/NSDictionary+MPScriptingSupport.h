//
//  NSDictionary+MPScriptingSupport.h
//  Feather
//
//  Created by Matias Piipari on 10/05/2015.
//  Copyright (c) 2015 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (MPScriptingSupport)

/** A method to convert an NSAppleEventDescriptor into an NSDictionary. */
+ (NSDictionary *)scriptingRecordWithDescriptor:(NSAppleEventDescriptor *)inDesc;

@end
