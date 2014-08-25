//
//  MPScriptingDefinitionManager.h
//  Feather
//
//  Created by Matias Piipari on 26/08/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

/** Parses an SDEF file and maps the four-letter codes to their type names and Cocoa types. */
@interface MPScriptingDefinitionManager : NSObject

/** A type string formatted name for a code. */
- (NSArray *)typesForCode:(FourCharCode)code;

- (FourCharCode)codeForType:(NSString *)type;

+ (instancetype)sharedInstance;

@end