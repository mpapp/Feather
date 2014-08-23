//
//  MPScriptingSupport.m
//  Feather
//
//  Created by Matias Piipari on 18/08/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import "CBLDocument+MPScriptingSupport.h"
#import <Foundation/Foundation.h>

@implementation CBLDocument (MPScriptingSupport)

- (id)objectSpecifier {
    assert(self.modelObject);
    NSScriptObjectSpecifier *containerRef = [(id)self.modelObject objectSpecifier];
    assert(containerRef);
    
    NSScriptClassDescription *classDesc = [NSScriptClassDescription classDescriptionForClass:self.modelObject.class];
    return [[NSPropertySpecifier alloc] initWithContainerClassDescription:classDesc
                                                       containerSpecifier:containerRef
                                                                      key:@"document"];
}

@end