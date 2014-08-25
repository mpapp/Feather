//
//  MPScriptingDefinitionManager.m
//  Feather
//
//  Created by Matias Piipari on 26/08/2014.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#import "MPScriptingDefinitionManager.h"

#import <Feather/Feather.h>
#import <Feather/NSString+MPExtensions.h>
#import <Feather/NSBundle+MPExtensions.h>

@interface MPScriptingDefinitionManager ()
@property (readonly) NSDictionary *typeMap;
@property (readonly) NSDictionary *codeMap;
@end

@implementation MPScriptingDefinitionManager

- (instancetype)init {
    @throw [[MPInitIsPrivateException alloc] initWithSelector:_cmd];
}

- (instancetype)initWithSDEFDocument:(NSXMLDocument *)document error:(NSError **)error {
    self = [super init];
    
    if (self) {
        NSMutableDictionary *tMap = [NSMutableDictionary dictionary];
        NSMutableDictionary *cMap = [NSMutableDictionary dictionary];
        for (NSXMLElement *elem in [document nodesForXPath:@"//*[@code]" error:error]) {
            NSString *code = [[elem attributeForName:@"code"] stringValue];
            NSString *type = [[elem attributeForName:@"type"] stringValue];
            
            if (!type) {
                NSLog(@"No type for '%@'", code);
                continue;
            }
            
            if (!tMap[code]) {
                tMap[code] = [NSMutableSet set];
            }
            [tMap[code] addObject:type];
            
            
            assert(!cMap[code]);
            cMap[type] = code;
        }
    }
    
    return self;
}

- (NSArray *)typesForCode:(FourCharCode)code {
    return self.typeMap[[NSString stringWithOSType:code]];
}

- (FourCharCode)codeForType:(NSString *)type {
    return [self.codeMap[type] OSType];
}

#pragma mark -

+ (instancetype)sharedInstance {
    static MPScriptingDefinitionManager *o = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *err = nil;
        
        NSString *sdefPath = [[NSBundle appBundle] infoDictionary][@"OSAScriptingDefinition"];
        assert(sdefPath); // will this work also for MPFoundation? Probably not?
        NSString *sdefBasename = [sdefPath stringByDeletingPathExtension];
        
        NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSBundle.appBundle URLForResource:sdefBasename withExtension:@"sdef"] options:0 error:&err];
        assert(doc);
        assert(!err);
        
        o = [[self alloc] initWithSDEFDocument:doc error:&err];
        assert(!err);
    });
    
    return nil;
}

@end
