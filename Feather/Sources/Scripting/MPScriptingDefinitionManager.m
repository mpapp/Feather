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
@property (readonly) NSDictionary *codeMap;
@property (readonly) NSDictionary *propertyNameMap;
@property (readonly) NSDictionary *cocoaPropertyNameMap;
@property (readonly) NSDictionary *typeNameMap;
@property (readonly) NSDictionary *propertyTypeMap;
@end

@implementation MPScriptingDefinitionManager

- (instancetype)init {
    @throw [[MPInitIsPrivateException alloc] initWithSelector:_cmd];
}

- (instancetype)initWithSDEFDocument:(NSXMLDocument *)document error:(NSError **)error {
    self = [super init];
    
    if (self) {
        NSMutableDictionary *cocoaPropertyMap = [NSMutableDictionary dictionary];
        NSMutableDictionary *propertyMap = [NSMutableDictionary dictionary];
        NSMutableDictionary *typeMap = [NSMutableDictionary dictionary];
        NSMutableDictionary *codeMap = [NSMutableDictionary dictionary];
        NSMutableDictionary *nameMap = [NSMutableDictionary dictionary];

        for (NSXMLElement *elem in [document nodesForXPath:@"//*[@code]" error:error]) {
            
            if ([[elem name] isEqualToString:@"suite"])
                continue;
            
            NSString *code = [elem attributeForName:@"code"].stringValue;
            NSString *type = [elem attributeForName:@"type"].stringValue;
            NSString *name = [elem attributeForName:@"name"].stringValue;
            
            // property element should always have a 'type' field filled in or a 'type' child element.
            if ([elem.name isEqualToString:@"property"]) {
                
                NSArray *typeNodes = [elem nodesForXPath:@"type" error:error];
                
                NSAssert(!propertyMap[code] || [propertyMap[code] isEqual:name], @"Ambiguous code <=> name mapping: %@", code, propertyMap[code]);
                propertyMap[code] = name;
                
                if (!typeMap[code])
                    typeMap[code] = [NSMutableSet set];
                
                if (typeNodes.count == 0) {
                    NSAssert(type, @"Property element %@ lacks 'type' field", elem);
                    
                    [typeMap[code] addObject:type];
                    
                    // only specific code combinations are expected to be synonymous.
                    if (codeMap[code])
                        assert([self code:code isSynonymousToCode:codeMap[code]]);

                    codeMap[type] = code;
                } else {
                    for (NSXMLElement *typeNode in typeNodes) {
                        NSString *typeAttrib = [typeNode attributeForName:@"type"].stringValue;
                        
                        BOOL isList = [typeNode attributeForName:@"list"];
                        NSString *t = isList ? typeAttrib : [@"list:%@" stringByAppendingString:typeAttrib];
                        
                        [typeMap[code] addObject:t];
                        
                        // only specific code combinations are expected to be synonymous.
                        if (codeMap[code])
                            assert([self code:code isSynonymousToCode:codeMap[code]]);

                        codeMap[t] = code;
                    }
                }
                
                NSString *cocoaKey = nil;
                // 'pnam' and 'ID  ' have various synonyms. we send them out below as just 'name' and 'identifier' which the receiver needs to be able to handle.
                if (![code isEqualToString:@"pnam"] && ![code isEqualToString:@"ID  "]) {
                    NSXMLElement *cocoaElem = [[elem nodesForXPath:@"cocoa" error:error] firstObject];
                    if (cocoaElem) {
                        cocoaKey = [[cocoaElem attributeForName:@"key"] stringValue];
                        NSAssert(cocoaKey, @"cocoa tag %@ is missing attribute 'key'", cocoaElem);
                    } else {
                        NSArray *words = [name componentsSeparatedByString:@" "];
                        NSString *firstWord = [words firstObject];
                        if (!firstWord.isAllUpperCase)
                            cocoaKey = [name camelCasedString];
                        else if (words.count == 1) {
                            cocoaKey = [firstWord camelCasedString];
                        }
                        else {
                            cocoaKey = [[firstWord camelCasedString] stringByAppendingString:[[words subarrayFromIndex:1] componentsJoinedByString:@""]];
                        }
                    }
                    
                } else if ([code isEqualToString:@"pnam"]) {
                    cocoaKey = @"name";
                } else if ([code isEqualToString:@"ID  "]) {
                    cocoaKey = @"identifier";
                }
                
                if (![code isEqualToString:@"pnam"] && ![code isEqualToString:@"ID  "])
                    assert(!cocoaPropertyMap[code] || [cocoaPropertyMap[code] isEqualToString:cocoaKey]);
                
                if (code && cocoaKey)
                    cocoaPropertyMap[code] = cocoaKey;
            }
            
            
            if (name
                && ([elem.name isEqualToString:@"class"]
                    || [elem.name isEqualToString:@"enumeration"]
                    || [elem.name isEqualToString:@"enumerator"]
                    || [elem.name isEqualToString:@"command"]
                    || [elem.name isEqualToString:@"value-type"])) {
                    
                NSAssert(!nameMap[code]
                         || [nameMap[code] isEqualToString:name],
                         @"Inconsistent type name detected for code: %@ != %@", code, nameMap[code]);
                
                nameMap[code] = name;
            }
            
        }
        
        _propertyNameMap = [propertyMap copy];
        _cocoaPropertyNameMap = [cocoaPropertyMap copy];
        _propertyTypeMap = [typeMap copy];
        _codeMap = [codeMap copy];
        _typeNameMap = [nameMap copy];
    }
    
    return self;
}

- (BOOL)code:(NSString *)code isSynonymousToCode:(NSString *)anotherCode {
    return [[self synonymousPairs] firstObjectMatching:^BOOL(NSSet *pair) {
        assert(pair.count == 2);
        return [pair containsObject:code] && [pair containsObject:anotherCode];
    }] != nil;
}

- (NSArray *)synonymousPairs {
    return @[[NSSet setWithObjects:@"kfil", @"file", nil]];
}

- (NSSet *)propertyTypesForCode:(FourCharCode)code {
    return self.propertyTypeMap[[NSString stringWithOSType:code]];
}

- (NSString *)propertyNameForCode:(NSString *)code {
    return self.propertyNameMap[[NSString stringWithOSType:code]];
}

- (NSString *)cocoaPropertyNameForCode:(FourCharCode)code {
    return self.cocoaPropertyNameMap[[NSString stringWithOSType:code]];
}

- (FourCharCode)codeForPropertyType:(NSString *)type {
    return [self.codeMap[type] OSType];
}

- (NSString *)typeNameForCode:(FourCharCode)code {
    return self.typeNameMap[[NSString stringWithOSType:code]];
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
    
    return o;
}

@end
