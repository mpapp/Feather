//
//  NSDictionary+MPScriptingSupport.m
//  Feather
//
//  Created by Matias Piipari on 10/05/2015.
//  Copyright (c) 2015 Matias Piipari. All rights reserved.
//

#import <FeatherExtensions/FeatherExtensions.h>
#import "MPScriptingDefinitionManager.h"
#import "NSDictionary+MPScriptingSupport.h"

@implementation NSDictionary (MPScriptingSupport)

+ (id)scriptingRecordWithDescriptor:(NSAppleEventDescriptor *)inDesc {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    
    for (NSUInteger i = 0; i < [inDesc numberOfItems]; i++) {
        AEKeyword childDescKey = [inDesc keywordForDescriptorAtIndex:i + 1];
        
        // usrf key means a dictionary with text type keys (at least)
        if ([[NSString stringWithOSType:childDescKey] isEqualToString:@"usrf"]) {
            NSAppleEventDescriptor *vals = [inDesc descriptorForKeyword:childDescKey];
            
            NSString *name = nil;
            NSString *value = nil;
            
            // 1-indexed, just to be different!
            NSInteger i = 1;
            NSInteger count = vals.numberOfItems;
            for ( ; i <= count; i++) {
                NSAppleEventDescriptor *desc = [vals descriptorAtIndex:i];
                
                NSString *s = [desc stringValue];
                if (name) {
                    value = s;
                    d[name] = value;
                    name = nil;
                    value = nil;
                } else {
                    name = s;
                }
            }
        } else {
            NSString *propertyName = [[MPScriptingDefinitionManager sharedInstance] cocoaPropertyNameForCode:childDescKey];
            
            NSAppleEventDescriptor *childDesc = [inDesc descriptorAtIndex:i + 1];
            d[propertyName] = childDesc.stringValue;
        }
    }
    
    return [d copy];
}

@end
