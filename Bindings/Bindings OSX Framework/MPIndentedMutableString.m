//
//  MPStringIndenter.m
//  Bindings
//
//  Created by Matias Piipari on 11/10/2014.
//  Copyright (c) 2014-2015 Manuscripts.app Limited. All rights reserved.
//

#import "MPIndentedMutableString.h"
#import <Feather/RegexKitLite.h>

@interface MPIndentedMutableString ()
@property (readonly) NSMutableString *mutableString;
@property (readwrite) NSUInteger indentationLevel;
@property (readwrite) NSUInteger indentationSpaceCount;
@end

@implementation MPIndentedMutableString

- (instancetype)init {
    return [self initWithIndentationSpaceCount:4];
}

- (instancetype)initWithIndentationSpaceCount:(NSUInteger)indentationSpaceCount {
    self = [super init];
    
    if (self) {
        _mutableString = [NSMutableString new];
        _indentationSpaceCount = indentationSpaceCount;
    }
    
    return self;
}

- (void)indent:(void(^)())block {
    self.indentationLevel += 1;
    block();
    self.indentationLevel -= 1;
}

+ (NSString *)indentationStringForLevel:(NSUInteger)indentationLevel
                  indentationSpaceCount:(NSUInteger)spaceCount {
    NSMutableString *str = [NSMutableString new];
    
    for (NSUInteger i = 0; i < indentationLevel * spaceCount; i++) {
        [str appendFormat:@" "];
    }
    
    return str.copy;
}

- (void)appendString:(NSString *)string {
    [self.mutableString appendString:string];
}

- (void)appendLine:(NSString *)indentedString {
    NSArray *components = [indentedString componentsSeparatedByString:@"\n"];
    
    for (NSUInteger i = 0, count = components.count; i < count; i++) {
        NSMutableString *string = components[i];
        
        [self.mutableString appendFormat:@"%@%@",
         [self.class indentationStringForLevel:self.indentationLevel
                         indentationSpaceCount:self.indentationSpaceCount], string];
        
        if (count > 1 && i < (count - 1))
            [self.mutableString appendString:@"\n"];
    }
}

- (void)appendFormat:(NSString *)format , ... {
    va_list arglist;
    va_start(arglist, format);
    [self appendString:[[NSString alloc] initWithFormat:format arguments:arglist]];
}

- (NSString *)stringRepresentation {
    return self.mutableString.copy;
}

- (id)copyWithZone:(NSZone *)zone {
    return self.stringRepresentation;
}

@end