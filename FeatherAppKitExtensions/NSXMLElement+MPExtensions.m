//
//  MPExtensions.m
//  Manuscripts
//
//  Created by Matias Piipari on 29/06/2014.
//  Copyright (c) 2014-2015 Manuscripts.app Limited. All rights reserved.
//


#import "NSXMLElement+MPExtensions.h"

@import FeatherExtensions;
@import P2Core.NSString_P2Extensions;

const MPTextContentOffset MPTextContentOffsetError = NSIntegerMin;
const MPTextContentOffset MPTextContentOffsetNotFound = -1;
const MPTextContentOffset MPTextContentOffsetBeginning = 0;
const MPTextContentOffset MPTextContentOffsetEnd = NSIntegerMax;

const NSString *_Nonnull MPXMLElementExtensionsErrorDomain = @"MPXMLElementExtensionsErrorDomain";

//
// Note: the options are almost `NSXMLNodePreserveAll`, but with `NSXMLNodePreserveCharacterReferences` dropped,
// because including it causes valid documents with text nodes containing &lt; *and* the # character to expand
// the < such that XMLString output from the document cannot then later be parsed again. Sigh.
//
const NSXMLNodeOptions MPDefaultXMLDocumentParsingOptions = (NSXMLNodeLoadExternalEntitiesNever |
                                                             NSXMLNodePreserveNamespaceOrder |
                                                             NSXMLNodePreserveAttributeOrder |
                                                             NSXMLNodePreserveEntities |
                                                             NSXMLNodePreservePrefixes |
                                                             NSXMLNodePreserveCDATA |
                                                             NSXMLNodePreserveWhitespace |
                                                             NSXMLNodePromoteSignificantWhitespace |
                                                             NSXMLNodePreserveEmptyElements |
                                                             NSXMLNodeUseDoubleQuotes);

const NSXMLNodeOptions MPDefaultXMLDocumentOutputOptions = (NSXMLNodePreserveNamespaceOrder |
                                                            NSXMLNodePreserveAttributeOrder |
                                                            NSXMLNodePreserveEntities |
                                                            NSXMLNodePreservePrefixes |
                                                            NSXMLNodePreserveCDATA |
                                                            NSXMLNodePreserveWhitespace |
                                                            NSXMLNodePromoteSignificantWhitespace |
                                                            NSXMLNodePreserveEmptyElements |
                                                            NSXMLNodeUseDoubleQuotes);

NSString *const MPXMLElementErrorDomain = @"MPXMLElementErrorDomain";

typedef NS_ENUM(NSInteger, MPXMLElementErrorCode) {
    MPXMLElementErrorCodeInnerXMLElementNotFound = 1,
    MPXMLElementErrorCodeTextNodeNotFound = 2,
    MPXMLElementErrorCodeFailedToParseXMLString = 99
};

@interface NSCharacterSet (MPExtensions)
+ (id)unicodeGremlinCharacterSet;
@end

@implementation NSCharacterSet (MPExtensions)

+ (id)unicodeGremlinCharacterSet {
    static dispatch_once_t pred = 0;
    static id UnicodeGremlinCharacterSet = nil;
    dispatch_once(&pred,
                  ^{
                      UnicodeGremlinCharacterSet = [[NSMutableCharacterSet alloc] init];
                      [UnicodeGremlinCharacterSet formUnionWithCharacterSet:[NSCharacterSet illegalCharacterSet]];
                      [UnicodeGremlinCharacterSet formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
                      [UnicodeGremlinCharacterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange(0xFFF0UL, 0xFFFFUL)]];
                      
                      // private use area
                      [UnicodeGremlinCharacterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange(0xE000UL, 0xF8FFUL)]];
                      
                      // supplementary private use A
                      [UnicodeGremlinCharacterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange(0xF0000UL, 0xFFFFFUL)]];
                      
                      // supplementary private use B
                      [UnicodeGremlinCharacterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithRange:NSMakeRange(0x100000UL, 0x10FFFFUL)]];
                      
                      UnicodeGremlinCharacterSet = [UnicodeGremlinCharacterSet copy];
                  });
    return UnicodeGremlinCharacterSet;
}

@end


@implementation NSXMLElement (MPExtensions)

+ (NSXMLElement *)XMLElementFromHTMLString:(NSString *)HTML
                              tidyDocument:(out NSXMLDocument *__autoreleasing __nullable *__nullable)outDocument
                                     error:(NSError *__autoreleasing *)error
{
    NSString *cleanXMLString = [[HTML stringByRemovingInvalidUTF8EncodedXMLCharacters] XMLStringByFixingPossiblyBrokenXMLNamespaces];
    
    if (!cleanXMLString)
    {
        if (error) {
            *error = [NSError errorWithDomain:MPXMLElementErrorDomain code:MPXMLElementErrorCodeFailedToParseXMLString userInfo:@{NSLocalizedDescriptionKey: @"Cannot parse nil into an XML document"}];
        }
        return nil;
    }
    
    NSXMLDocument *document = nil;
    
    @try
    {
        document = [[NSXMLDocument alloc] initWithXMLString:cleanXMLString
                                                    options:MPDefaultXMLDocumentParsingOptions
                                                      error:error];
        if (!document) {
            return nil;
        }
    }
    @catch (NSException *exception)
    {
        if (error) {
            *error = [NSError errorWithDomain:MPXMLElementErrorDomain code:MPXMLElementErrorCodeFailedToParseXMLString userInfo:@{NSLocalizedDescriptionKey: MPStringWithFormat(@"Cannot parse HTML into an XML document: %@", HTML)}];
        }
        return nil;
    }
    
    document.documentContentKind = NSXMLDocumentXMLKind;
    
    if (outDocument) {
        *outDocument = document;
    }
    
    return document.rootElement;
}

+ (NSXMLElement *)XMLElementFromHTMLString:(NSString *)HTML innerElements:(out NSArray<NSXMLElement *> *__autoreleasing  _Nonnull *)innerElements forXPaths:(NSArray<NSString *> *)XPaths error:(out NSError *__autoreleasing  _Nullable *)error
{
    NSXMLDocument *document = nil;
    NSXMLElement *rootElement = [self XMLElementFromHTMLString:HTML tidyDocument:&document error:error];
    
    if (rootElement && innerElements && XPaths)
    {
        NSMutableArray *innerElementResults = [NSMutableArray new];
        
        for (NSString *XPath in XPaths)
        {
            NSArray *nodes = nil;
            
            if ([XPath isEqualToString:@"."]) {
                nodes = @[rootElement];
            }
            else
            {
                nodes = [rootElement nodesForXPath:XPath error:error];
                if (!nodes) {
                    return nil;
                }
                
                nodes = [nodes filteredArrayMatching:^BOOL(id node) {
                    return [node isKindOfClass:NSXMLElement.class];
                }];
            }
            
            [innerElementResults addObjectsFromArray:nodes];
        }
        
        *innerElements = [innerElementResults copy];
    }
    
    return rootElement;
}

+ (NSXMLElement *)XMLElementFromString:(NSString *)XMLString error:(NSError *__autoreleasing *)error
{
    NSString *cleanXMLString = [XMLString stringByRemovingInvalidUTF8EncodedXMLCharacters];
    
    if (!cleanXMLString) {
        if (error) {
            *error = [NSError errorWithDomain:MPXMLElementErrorDomain
                                         code:MPXMLElementErrorCodeFailedToParseXMLString
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Bad XML string:\n%@", XMLString]
                                                }];
        }
        return nil;
    }
    
    NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:cleanXMLString error:error];
    return element;
}

- (NSXMLElement *)_recreateClean
{
    // Replace root element so that we get rid of DOCTYPE and the XHTML namespace
    NSXMLElement *cleanNewElement = [NSXMLElement elementWithName:self.name];
    
    for (NSXMLNode *node in self.children)
    {
        [node detach];
        [cleanNewElement addChild:node];
    }
    
    return cleanNewElement;
}

#pragma mark Internal helpers: whitespace

/**
 Determine how many characters of preserved leading whitespace has been marked at parsing time by
 
 Note: looking at LLDB, such elements appear to be instances NSXMLFidelityElement, with an ivar named _startWhitespace denoting the leading whitespace as a string, but there isn't a kosher way to get to it, so determining it via this concoction instead.
 */
- (NSUInteger)leadingWhitespaceLength
{
    NSString *s = [self XMLStringWithOptions:MPDefaultXMLDocumentOutputOptions];
    NSUInteger l = s.length;
    NSUInteger trimmedLength = [s stringByTrimmingLeadingWhitespace].length;
    NSUInteger d = (l - trimmedLength);
    return d;
}

/** See above. Only difference: the ivar appears to be named _endWhitespace. */
- (NSUInteger)trailingWhitespaceLength
{
    NSString *s = [self XMLStringWithOptions:MPDefaultXMLDocumentOutputOptions];
    NSUInteger l = s.length;
    NSUInteger trimmedLength = [s stringByTrimmingTrailingWhitespace].length;
    NSUInteger d = (l - trimmedLength);
    return d;
}

/*
 - (void)enumerateTextNodeValuesIncludingPreservedSpaceVisitElementsAtLeastOnce:(BOOL)visitElementsAtLeastOnce
 withEnumerator:(MPXMLNodeStringValueIterator)enumerator
 {
 static NSArray *preservedWhitespaceStrings = nil;
 if (!preservedWhitespaceStrings) {
 preservedWhitespaceStrings = @[@"", @" ", @"  ", @"   ", @"    ", @"     ", @"      ", @"       ", @"        ", @"         ", @"          ", @"           "];
 }
 
 NSMutableSet *visitedElements = [NSMutableSet new];
 NSXMLNode *node = [self.children firstObject];
 BOOL keepGoing = YES;
 
 while (node && node.level > self.level)
 {
 NSLog(@"Examining: |%@|", node);
 
 NSXMLNode *next = nil;
 
 if (node.kind == NSXMLTextKind)
 {
 // Enumerator may detach node, so we take note of the next one already here
 next = node.nextSibling;
 if (!next) {
 next = node.nextNode;
 }
 
 keepGoing = enumerator(node, node.stringValue);
 }
 else if (node.kind == NSXMLElementKind)
 {
 BOOL alreadyEncountered = [visitedElements containsObject:node];
 
 // Determine next node
 if (!alreadyEncountered) {
 next = node.children.firstObject;
 }
 if (!next) {
 next = node.nextSibling;
 }
 if (!next) {
 next = node.nextNode;
 }
 
 if (alreadyEncountered) // TODO: this is the weak spot here
 {
 NSUInteger l = [(NSXMLElement *)node trailingWhitespaceLength];
 if (l > 0) {
 keepGoing = enumerator(node, preservedWhitespaceStrings[l]);
 }
 }
 else
 {
 NSUInteger l = [(NSXMLElement *)node leadingWhitespaceLength];
 if (l > 0 || visitElementsAtLeastOnce) {
 keepGoing = enumerator(node, preservedWhitespaceStrings[l]);
 }
 }
 }
 
 if (!keepGoing) {
 break;
 }
 
 [visitedElements addObject:node];
 node = next;
 }
 }
 */

#pragma mark HTML class attribute manipulation

- (BOOL)addClass:(NSString *)klass
{
    NSXMLNode *classAttribute = [self attributeForName:@"class"];
    if (!classAttribute)
    {
        classAttribute = [[NSXMLNode alloc] initWithKind:NSXMLAttributeKind];
        classAttribute.name = @"class";
        [self addAttribute:classAttribute];
    }
    
    NSString *classes = classAttribute.stringValue;
    if (classes)
        classes = [classes stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (classes.length == 0)
    {
        classAttribute.stringValue = klass;
    }
    else if ([classes containsSubstring:klass] && [[classes componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] containsObject:klass])
    {
        return NO; // Don't add if class is already included in attribute value
    }
    else
    {
        classAttribute.stringValue = MPStringWithFormat(@"%@ %@", classes, klass);
    }
    
    return YES;
}

- (BOOL)hasClass:(NSString *)klass
{
    NSXMLNode *classAttribute = [self attributeForName:@"class"];
    if (classAttribute)
    {
        NSArray *classes = [classAttribute.stringValue componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([classes containsObject:klass])
            return YES;
    }
    return NO;
}

- (BOOL)hasID
{
    return [self attributeForName:@"id"].stringValue.length > 0;
}

- (BOOL)removeClass:(NSString *)klass
{
    NSXMLNode *classAttribute = [self attributeForName:@"class"];
    if (classAttribute)
    {
        NSArray *classes = [classAttribute.stringValue componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([classes containsObject:klass])
        {
            classAttribute.stringValue = [[classes arrayByRemovingObject:klass] componentsJoinedByString:@" "];
            return YES;
        }
    }
    return NO;
}

- (void)setAttributeNamed:(NSString *)attributeName stringValue:(NSString *)value
{
    NSXMLNode *attribute = [NSXMLNode attributeWithName:attributeName stringValue:value];
    [self removeAttributeForName:attributeName];
    [self addAttribute:attribute];
}

- (void)setAttributesFromElement:(NSXMLElement *)sourceElement
{
    NSMutableArray *attributes = [NSMutableArray new];
    
    for (NSXMLNode *sourceAttribute in sourceElement.attributes)
    {
        NSXMLNode *attribute = [NSXMLNode attributeWithName:sourceAttribute.name stringValue:sourceAttribute.stringValue];
        [attributes addObject:attribute];
    }
    
    [self setAttributes:attributes];
}

#pragma mark Attribute conveniences

- (BOOL)hasID:(NSString *)ID
{
    NSXMLNode *IDAttribute = [self attributeForName:@"id"];
    if (IDAttribute) {
        BOOL has = [IDAttribute.stringValue isEqualToString:ID];
        return has;
    }
    return NO;
}

- (BOOL)hasAttribute:(NSString *)attributeName value:(NSString *)value
{
    NSXMLNode *attribute = [self attributeForName:attributeName];
    if (attribute) {
        BOOL has = [attribute.stringValue isEqualToString:value];
        return has;
    }
    return NO;
}

#pragma mark Node subtree traversal

/**
 
 Walk subtree of elements and text nodes starting from given descendant node, visiting each node exactly once.
 
 @param `startNode` descendant node to start visiting from (inclusive); if `nil`, will start from the first child node of this element
 @param `endNode` descendant node to stop visiting at (inclusive); if `nil`, will end at the last node in this element's subtree of nodes
 
 */
- (NSUInteger)visitNodesInSubtreeStartingFrom:(NSXMLNode *)startNode
                                         upTo:(NSXMLNode *)endNode
                                      visitor:(MPXMLNodeVisitor)visitor
{
    if (self.children.count < 1) {
        return 0;
    }
    
    NSMutableArray *queue = [NSMutableArray new];
    [queue pushObjectsInArray:self.children];
    
    BOOL shouldVisit = (startNode != nil) ? NO : YES;
    NSUInteger visitCount = 0;
    
    while (queue.count > 0)
    {
        NSXMLNode *node = [queue popObject];
        [queue pushObjectsInArray:node.children];
        
        if (node == startNode && !shouldVisit) {
            shouldVisit = YES;
        }
        
        if (shouldVisit)
        {
            //NSLog(@"Visiting |%@|", node);
            
            visitCount++;
            
            if (!visitor(node)) {
                break;
            }
        }
        else {
            //NSLog(@"Skipping |%@|", node);
        }
        
        if (node == endNode) {
            break;
        }
    }
    
    return visitCount;
}

- (NSUInteger)visitNodesInSubtreeStartingFrom:(NSXMLNode *)startNode visitor:(MPXMLNodeVisitor)visitor
{
    return [self visitNodesInSubtreeStartingFrom:startNode upTo:nil visitor:visitor];
}

- (NSUInteger)visitNodesInSubtreeUpTo:(NSXMLNode *)endNode visitor:(MPXMLNodeVisitor)visitor
{
    return [self visitNodesInSubtreeStartingFrom:nil upTo:endNode visitor:visitor];
}

- (NSUInteger)visitAllNodesInSubtree:(MPXMLNodeVisitor)visitor
{
    return [self visitNodesInSubtreeStartingFrom:nil upTo:nil visitor:visitor];
}


#pragma mark Element subtree searching

- (NSArray *)childElements
{
    NSArray *elements = [self.children filteredArrayMatching:^BOOL(id node) {
        return [node isKindOfClass:NSXMLElement.class];
    }];
    
    return elements;
}

- (NSXMLElement *)findXMLElementMatching:(MPFirstMatchingXMLElementTest)test
{
    NSXMLNode *node = [self.children firstObject];
    
    while (node && node.level > self.level)
    {
        if ([node isKindOfClass:NSXMLElement.class] && test((NSXMLElement *)node)) {
            return (NSXMLElement *)node;
        }
        node = [node nextNode];
    }
    
    return nil;
}

- (NSXMLElement *)findXMLElementByName:(NSString *)elementName
                                    ID:(NSString *)ID
                                 class:(NSString *)klass
                       attributeValues:(NSDictionary *)attributeValues
{
    NSXMLElement *element = [self findXMLElementMatching:^BOOL(NSXMLElement *element)
                             {
                                 BOOL nameMatch = !elementName || [element.name isEqualToString:elementName];
                                 if (!nameMatch) {
                                     return NO;
                                 }
                                 
                                 BOOL IDMatch = !ID || [element hasID:ID];
                                 if (!IDMatch) {
                                     return NO;
                                 }
                                 
                                 BOOL classMatch = !klass || [element hasClass:klass];
                                 if (!classMatch) {
                                     return NO;
                                 }
                                 
                                 if (attributeValues)
                                 {
                                     for (NSString *key in attributeValues.allKeys) {
                                         if (![element hasAttribute:key value:attributeValues[key]]) {
                                             return NO;
                                         }
                                     }
                                 }
                                 
                                 return YES;
                             }];
    
    return element;
}

- (NSXMLElement *)findXMLElementByName:(NSString *)elementName
{
    return [self findXMLElementByName:elementName ID:nil class:nil attributeValues:nil];
}

- (NSArray *)findXMLElementsByNames:(NSArray *)elementNames
{
    return [self findXMLElementsPassing:^BOOL(NSXMLElement *element, BOOL *stop) {
        return [elementNames containsObject:element.name];
    }];
}

- (NSXMLElement *)findXMLElementByID:(NSString *)elementID
{
    return [self findXMLElementByName:nil ID:elementID class:nil attributeValues:nil];
}

- (NSXMLElement *)findXMLElementByClass:(NSString *)hasClass
{
    return [self findXMLElementByName:nil ID:nil class:hasClass attributeValues:nil];
}

- (NSArray *)findXMLElementsByClass:(NSString *)hasClass
{
    return [self findXMLElementsPassing:^BOOL(NSXMLElement *element, BOOL *stop) {
        return [element hasClass:hasClass];
    }];
}

- (NSXMLElement *)findXMLElementByAttributeValues:(NSDictionary *)attributeValues
{
    return [self findXMLElementByName:nil ID:nil class:nil attributeValues:attributeValues];
}

- (NSArray *)findXMLElementsPassing:(MPMatchingXMLElementsTest)test
{
    NSMutableArray *matchingElements = [NSMutableArray new];
    NSXMLNode *node = [self.children firstObject];
    BOOL stop = NO;
    
    while (node && node.level > self.level)
    {
        if ([node isKindOfClass:NSXMLElement.class] && test((NSXMLElement *)node, &stop)) {
            [matchingElements addObject:node];
        }
        if (stop) {
            break;
        }
        node = [node nextNode];
    }
    
    return [matchingElements copy];
}

- (NSXMLElement *)previousElementSibling
{
    NSXMLNode *n = self.previousSibling;
    
    while (n)
    {
        if ([n isKindOfClass:NSXMLElement.class]) {
            return (NSXMLElement *)n;
        }
        n = [n previousSibling];
    }
    return nil;
}

- (NSXMLElement *)nextElementSibling
{
    NSXMLNode *n = self.nextSibling;
    
    while (n)
    {
        if ([n isKindOfClass:NSXMLElement.class]) {
            return (NSXMLElement *)n;
        }
        n = [n nextSibling];
    }
    return nil;
}

- (BOOL)containsDescendantNode:(NSXMLNode *)node
{
    NSXMLNode *n = node.parent;
    while (n)
    {
        if (n == self) {
            return YES;
        }
        n = n.parent;
    }
    
    return NO;
}

+ (NSXMLElement *)commonAncestorElementOf:(NSXMLElement *)firstElement and:(NSXMLElement *)secondElement
{
    NSXMLElement *el1, *el2;
    
    if (firstElement.level <= secondElement.level) {
        el1 = firstElement;
        el2 = secondElement;
    }
    else {
        el1 = secondElement;
        el2 = firstElement;
    }
    
    NSXMLElement *p = (NSXMLElement *)el1.parent;
    while (p)
    {
        if ([p containsDescendantNode:el2]) {
            return p;
        }
        p = (NSXMLElement *)p.parent;
    }
    
    return nil;
}

#pragma mark String representations

- (NSString *)innerXMLString
{
    NSArray *strings = [self.children nilFilteredMapUsingBlock:^id(NSXMLNode *n, NSUInteger idx) {
        if (n.kind == NSXMLElementKind) {
            return [(NSXMLElement*)n XMLStringWithOptions:MPDefaultXMLDocumentOutputOptions];
        }
        else if (n.kind == NSXMLTextKind) {
            return [n.stringValue stringByEscapingAsXMLTextContent];
        }
        
        return nil;
    }];
    
    NSString *s = [strings componentsJoinedByString:@""];
    return s;
}

- (void)mp_setInnerXMLNodes:(NSArray *)nodes
{
    [self.children enumerateObjectsUsingBlock:^(id node, NSUInteger index, BOOL *stop) {
        [node detach];
    }];
    [nodes enumerateObjectsUsingBlock:^(id node, NSUInteger idx, BOOL *stop) {
        [node detach];
        [self addChild:node];
    }];
}

/**
 Walk through this element's descendant elements and normalize whitespace, in-place.
 */
- (BOOL)normalizeWhitespaceWithinDescendantElementsNamed:(NSArray *)elementNames error:(out NSError *__autoreleasing*)error
{
    NSMutableArray *queue = [NSMutableArray new];
    [queue addObject:self];
    
    while ([queue count] > 0)
    {
        NSXMLNode *node = [queue popObject];
        
        if (node.kind == NSXMLElementKind && [elementNames containsObject:node.name])
        {
            NSXMLElement *element = (NSXMLElement *)node;
            NSString *normalizedXMLString = MPStringWithFormat(@"<wrap>%@</wrap>", [[element innerXMLString] stringByNormalizingWhitespace]);
            
            NSXMLDocument *tidyDocument = nil;
            NSXMLElement *el = [NSXMLElement XMLElementFromHTMLString:normalizedXMLString tidyDocument:&tidyDocument error:error];
            if (!el) {
                return NO;
            }
            
            [element mp_setInnerXMLNodes:el.children];
        }
        else
        {
            [queue pushObjectsInArray:node.children];
        }
    }
    
    return YES;
}

- (NSString *)prettyXMLString
{
    NSString *pretty = [self XMLStringWithOptions:(NSXMLNodePrettyPrint | NSXMLNodePreserveAll)];
    return pretty;
}

- (NSUInteger)textContentLength
{
    [self enforceExplicitPreservedSpace];
    
    NSXMLNode *node = [self.children firstObject];
    NSUInteger l = 0;
    
    while (node && node.level > self.level)
    {
        if (node.kind == NSXMLTextKind) {
            l += node.stringValue.length;
        }
        node = node.nextNode;
    }
    
    return l;
}

/*
 - (NSUInteger)textContentLength
 {
 __block NSUInteger l = 0;
 
 [self enumerateTextNodeValuesIncludingPreservedSpaceVisitElementsAtLeastOnce:NO
 withEnumerator:^BOOL(NSXMLNode *node, NSString *stringValue)
 {
 l += stringValue.length;
 return YES;
 }];
 
 MPAssertTrue(l >= [self _textContentLength]);
 return l;
 }*/

+ (NSString *)textContentForXMLString:(NSString *)XMLString error:(NSError *__autoreleasing *)error
{
    NSXMLDocument *tidyDocument = nil;
    NSXMLElement *XML = [NSXMLElement XMLElementFromHTMLString:XMLString tidyDocument:&tidyDocument error:error];
    if (!XML) {
        return nil;
    }
    
    NSString *t = [XML stringValue];
    return t;
}

+ (NSUInteger)textContentLengthForXMLString:(NSString *)XMLString error:(NSError *__autoreleasing *)error
{
    NSXMLDocument *tidyDocument = nil;
    NSXMLElement *XML = [NSXMLElement XMLElementFromHTMLString:XMLString tidyDocument:&tidyDocument error:error];
    if (!XML) {
        return NSNotFound;
    }
    
    NSUInteger l = [XML textContentLength];
    return l;
}

+ (MPTextContentOffset)textContentOffsetForXMLString:(NSString *)XMLString innerElementXPath:(NSString *)XPath innerOffset:(MPTextContentOffset)innerOffset error:(NSError **)error
{
    NSXMLDocument *tidyDocument = nil;
    NSXMLElement *XML = [NSXMLElement XMLElementFromHTMLString:XMLString tidyDocument:&tidyDocument error:error];
    if (!XML) {
        return MPTextContentOffsetError;
    }
    
    NSXMLElement *innerElement = XML;
    
    if (XPath && ![XPath isEqualToString:@"."])
    {
        NSArray *nodes = [XML nodesForXPath:XPath error:error];
        if (!nodes) {
            return MPTextContentOffsetError;
        }
        innerElement = nodes.firstObject;
    }
    
    if (innerElement)
    {
        MPTextContentOffset offset = [XML textContentOffsetForInnerXMLElement:innerElement textContentOffset:innerOffset];
        return offset;
    }
    
    return MPTextContentOffsetNotFound;
}

- (NSUInteger)textContentLengthBeforeNode:(NSXMLNode *)anchorNode
{
    [self enforceExplicitPreservedSpace];
    
    NSXMLNode *node = [self.children firstObject];
    NSUInteger l = 0;
    BOOL found = NO;
    
    while (node && node.level > self.level && node != anchorNode)
    {
        if (node.kind == NSXMLTextKind) {
            l += node.stringValue.length;
        }
        node = node.nextNode;
        
        if (node == anchorNode) {
            found = YES;
        }
    }
    
    if (!found) {
        return NSNotFound;
    }
    
    return l;
}

/*
 - (NSUInteger)textContentLengthBeforeNode:(NSXMLNode *)anchorNode
 {
 __block NSUInteger l = 0;
 __block BOOL found = NO;
 
 [self enumerateTextNodeValuesIncludingPreservedSpaceVisitElementsAtLeastOnce:YES
 withEnumerator:^BOOL(NSXMLNode *node, NSString *stringValue)
 {
 l += stringValue.length;
 if (node == anchorNode)
 {
 found = YES;
 return NO;
 }
 return YES;
 }];
 
 if (!found) {
 return NSNotFound;
 }
 
 MPAssertTrue(l == [self _textContentLengthBeforeNode:anchorNode]);
 return l;
 }
 */


#pragma mark Element structure manipulation

- (void)enforceExplicitPreservedSpace
{
    // Find elements with implicit leading or trailing space to fix
    NSMutableArray *fixes = [NSMutableArray new];
    
    [self visitAllNodesInSubtree:^BOOL(NSXMLNode * _Nonnull node)
     {
         if (node.kind == NSXMLElementKind)
         {
             NSUInteger l = [(NSXMLElement *)node leadingWhitespaceLength];
             NSUInteger t = [(NSXMLElement *)node trailingWhitespaceLength];
             if (l > 0 || t > 0) {
                 [fixes addObject:@[@(l), node, @(t)]];
             }
         }
         return YES;
     }];
    
    // Apply fixes
    for (NSArray *fix in fixes)
    {
        NSUInteger l = [fix[0] unsignedIntegerValue];
        NSXMLElement *el = fix[1];
        NSUInteger t = [fix[2] unsignedIntegerValue];
        
        NSXMLElement *parentElement = (NSXMLElement *)[el parent];
        NSUInteger i = [[parentElement children] indexOfObject:el];
        
        if (l > 0)
        {
            NSXMLNode *leadingTextNode = [NSXMLNode textWithStringValue:[@"" stringByPaddingToLength:l withString:@" " startingAtIndex:0]];
            [parentElement insertChild:leadingTextNode atIndex:i];
        }
        
        NSString *trimmedXMLString = [[el XMLStringWithOptions:MPDefaultXMLDocumentOutputOptions] stringByTrimmingWhitespace];
        NSXMLElement *trimmedElement = [NSXMLElement XMLElementFromString:trimmedXMLString error:nil];
        [parentElement removeChild:el];
        [parentElement insertChild:trimmedElement atIndex:i + 1];
        
        if (t > 0)
        {
            NSXMLNode *trailingTextNode = [NSXMLNode textWithStringValue:[@"" stringByPaddingToLength:t withString:@" " startingAtIndex:0]];
            [(NSXMLElement *)[el parent] insertChild:trailingTextNode atIndex:(i + 2)];
        }
    }
}

- (void)normalizeWhitespaceAllowLeading:(BOOL)allowLeadingWhitespace
                               trailing:(BOOL)allowTrailingWhitespace
{
    [self enforceExplicitPreservedSpace];
    
    NSXMLNode *node = [self.children firstObject];
    NSXMLNode *firstTextNode = [self firstContainedTextNode];
    NSXMLNode *lastTextNode = [self lastContainedTextNode];
    
    while (node && node.level > self.level)
    {
        BOOL isFirstTextNode = (node == firstTextNode);
        BOOL isLastTextNode = (node == lastTextNode);
        
        if (node.kind == NSXMLTextKind)
        {
            NSString *text = [node.stringValue stringByNormalizingWhitespaceAllowLeading:(isFirstTextNode && !allowLeadingWhitespace) ? NO : YES
                                                                      trailingWhitespace:(isLastTextNode && !allowTrailingWhitespace) ? NO : YES];
            
            if (![text isEqualToString:node.stringValue]) {
                node.stringValue = text;
            }
        }
        
        node = [node nextNode];
    }
}

- (void)collapse
{
    NSXMLElement *parent = (NSXMLElement *)self.parent;
    NSUInteger i = [parent.children indexOfObject:self];
    
    for (NSXMLNode *n in self.children)
    {
        [n detach];
        [parent insertChild:n atIndex:i];
        i++;
    }
    
    [self detach];
}

- (NSXMLElement *)wrapChildren:(NSArray *)nodes elementName:(NSString *)wrappingElementName
{
    NSArray *childNodes = [nodes filteredArrayMatching:^BOOL(id node) {
        return [(NSXMLNode *)node parent] == self;
    }];
    
    if (childNodes.count < 1) {
        return nil;
    }
    
    NSUInteger i = [self.children indexOfObject:childNodes[0]];
    NSAssert(i != NSNotFound, @"Did not encounter %@ amongst children %@", childNodes[0], self.children);
    
    NSXMLElement *el = [NSXMLElement elementWithName:wrappingElementName];
    
    for (NSXMLNode *n in childNodes)
    {
        [n detach];
        [el addChild:n];
    }
    
    [self insertChild:el atIndex:i];
    
    return el;
}

- (NSUInteger)deleteTextUpToOffset:(MPTextContentOffset)offset fromBeginningOfAncestorElement:(NSXMLElement *)rootElement
{
    [rootElement enforceExplicitPreservedSpace];
    
    NSUInteger deletedLength = 0;
    
    if (!rootElement) {
        rootElement = self;
    }
    
    MPTextContentOffset splitOffset = NSNotFound;
    NSXMLNode *textNodeToSplit = [self textNodeAtOffset:offset offsetWithinTextNode:&splitOffset];
    if (!textNodeToSplit || splitOffset == NSNotFound) {
        return 0;
    }
    
    // Delete text nodes preceding the one to split
    NSXMLNode *node = [rootElement.children firstObject];
    
    while (node && (node.level > rootElement.level) && (node != textNodeToSplit))
    {
        NSXMLNode *nextNode = [node nextNode]; // Take note of next node now, in case we end up detaching this one
        
        if (node.kind == NSXMLTextKind)
        {
            deletedLength += node.stringValue.length;
            [node detach];
        }
        else if (node.kind == NSXMLElementKind)
        {
            //
            // We may encounter strangeitude like elements whose string representation is @" <i>italic</i>" (i.e element with a leading space, what?!)
            // This happens for instance within structures like `<p>Plain <b>bold</b> <i>italic</i> text.</p>` where the space between the `<b>` and `<i>`
            // elements does not show up as a text node in this iteration.
            //
            // We compensate by the length delta of XMLString-as-is and XMLString-with-whitespace-trimmed.
            //
            NSString *s = [node XMLString];
            NSUInteger l = s.length;
            NSUInteger trimmedLength = [s stringByTrimmingWhitespace].length;
            if (trimmedLength < l) {
                deletedLength += (l - trimmedLength);
            }
        }
        
        node = nextNode;
    }
    
    // Split text node
    if (splitOffset > MPTextContentOffsetBeginning)
    {
        textNodeToSplit.stringValue = [textNodeToSplit.stringValue substringFromIndex:splitOffset];
        deletedLength += splitOffset;
    }
    
    // Remove empty elements preceding split offset, possibly created by detaching text nodes above
    BOOL didDetach = NO;
    
    do
    {
        node = [rootElement.children firstObject];
        didDetach = NO;
        
        while (node && (node.level > rootElement.level) && (node != textNodeToSplit))
        {
            NSXMLNode *nextNode = [node nextNode];
            
            if (node.kind == NSXMLElementKind && node.children.count == 0)
            {
                [node detach];
                didDetach = YES;
            }
            
            node = nextNode;
        }
    }
    while (didDetach); // Repeat until there are no further detachments, to be sure structures like <b><i></i></b> get cleaned up
    
    return deletedLength;
}

- (NSUInteger)deleteTextFromOffset:(MPTextContentOffset)offset toEndOfAncestorElement:(NSXMLElement *)rootElement
{
    [rootElement enforceExplicitPreservedSpace];
    
    __block NSUInteger deletedLength = 0;
    
    if (!rootElement) {
        rootElement = self;
    }
    
    MPTextContentOffset splitOffset = NSNotFound;
    NSXMLNode *textNodeToSplit = [self textNodeAtOffset:offset offsetWithinTextNode:&splitOffset];
    if (!textNodeToSplit || splitOffset == NSNotFound || splitOffset > self.textContentLength) {
        return 0;
    }
    
    // Determine elements and text nodes to delete (the tail following the split)
    NSMutableArray *nodesToDetach = [NSMutableArray new];
    
    [rootElement visitNodesInSubtreeStartingFrom:textNodeToSplit visitor:^BOOL(NSXMLNode *node)
     {
         if (node == textNodeToSplit) {
             return YES;
         }
         
         [nodesToDetach addObject:node];
         
         if (node.kind == NSXMLTextKind) {
             deletedLength += node.stringValue.length;
         }
         
         return YES;
     }];
    
    // Do the split
    if (splitOffset > MPTextContentOffsetBeginning)
    {
        NSUInteger oldLength = textNodeToSplit.stringValue.length;
        textNodeToSplit.stringValue = [textNodeToSplit.stringValue substringToIndex:splitOffset];
        deletedLength += (oldLength - textNodeToSplit.stringValue.length);
    }
    
    // Detach tail
    for (NSXMLNode *node in nodesToDetach)
    {
        [node detach];
    }
    
    /*NSXMLNode *node = textNodeToSplit.nextNode;
     
     while (node && (node.level > rootElement.level))
     {
     NSXMLNode *nextNode = [node nextNode]; // Take note of next node now, in case we end up detaching this one
     
     if (node.kind == NSXMLTextKind)
     {
     deletedLength += node.stringValue.length;
     [node detach];
     }
     
     node = nextNode;
     }
     
     // Remove empty elements following split offset, possibly created by detaching text in previous pass
     BOOL didDetach = NO;
     
     do
     {
     node = textNodeToSplit.nextNode;
     didDetach = NO;
     
     while (node && (node.level > rootElement.level))
     {
     NSXMLNode *nextNode = [node nextNode];
     
     if (node.kind == NSXMLElementKind && node.children.count == 0)
     {
     [node detach];
     didDetach = YES;
     }
     
     node = nextNode;
     }
     }
     while (didDetach); // Repeat until there are no further detachments, to be sure structures like <b><i></i></b> get cleaned up
     */
    
    return deletedLength;
}

- (BOOL)innerXMLElement:(out NSXMLElement **)innerElement atXPath:(NSString *)XPath error:(NSError *__autoreleasing *)error
{
    NSArray *nodes = [self nodesForXPath:XPath error:error];
    if (!nodes) {
        return NO;
    }
    
    NSXMLNode *n = nodes.firstObject;
    if (n && innerElement && [n isKindOfClass:NSXMLElement.class]) {
        *innerElement = (NSXMLElement *)n;
        return YES;
    }
    else if (innerElement) {
        *innerElement = nil;
    }
    
    return YES;
}

- (NSXMLNode *)firstContainedTextNode
{
    [self enforceExplicitPreservedSpace];
    
    __block NSXMLNode *t = nil;
    
    [self visitAllNodesInSubtree:^BOOL(NSXMLNode *node)
     {
         if (node.kind == NSXMLTextKind)
         {
             t = node;
             return NO;
         }
         return YES;
     }];
    
    return t;
    
    /*
     NSXMLNode *node = [self.children firstObject];
     
     while (node && node.level > self.level)
     {
     if (node.kind == NSXMLTextKind) {
     return node;
     }
     node = node.nextNode;
     }
     return nil;
     */
}

- (NSXMLNode *)lastContainedTextNode
{
    [self enforceExplicitPreservedSpace];
    
    __block NSXMLNode *t = nil;
    
    [self visitAllNodesInSubtree:^BOOL(NSXMLNode *node)
     {
         if (node.kind == NSXMLTextKind) {
             t = node;
         }
         return YES;
     }];
    
    return t;
    
    /*
     NSXMLNode *node = [self.children lastObject];
     
     while (node && node.level > self.level)
     {
     if (node.kind == NSXMLTextKind) {
     return node;
     }
     node = node.previousNode;
     }
     return nil;
     */
}

- (NSXMLNode *)textNodeAtOffset:(MPTextContentOffset)offset offsetWithinTextNode:(out MPTextContentOffset *)innerOffset
{
    [self enforceExplicitPreservedSpace];
    
    if (offset == MPTextContentOffsetBeginning)
    {
        NSXMLNode *node = [self firstContainedTextNode];
        if (innerOffset) {
            *innerOffset = MPTextContentOffsetBeginning;
        }
        return node;
    }
    if (offset == MPTextContentOffsetEnd)
    {
        NSXMLNode *node = [self lastContainedTextNode];
        if (innerOffset) {
            *innerOffset = MPTextContentOffsetEnd;
        }
        return node;
    }
    
    __block NSXMLNode *t = nil;
    __block MPTextContentOffset accumulatedOffset = 0;
    
    [self visitAllNodesInSubtree:^BOOL(NSXMLNode *node)
     {
         if (node.kind == NSXMLTextKind)
         {
             NSString *s = node.stringValue;
             MPTextContentOffset nodeEndOffset = accumulatedOffset + s.length;
             
             if (nodeEndOffset >= offset)
             {
                 if (innerOffset) {
                     *innerOffset = (offset - accumulatedOffset);
                 }
                 t = node;
                 return NO;
             }
             accumulatedOffset = nodeEndOffset;
         }
         return YES;
     }];
    
    return t;
    
    /*
     NSXMLNode *node = self.nextNode;
     MPTextContentOffset accumulatedOffset = 0;
     
     while (node && node.level > self.level)
     {
     if (node.kind == NSXMLTextKind)
     {
     NSString *s = node.stringValue;
     MPTextContentOffset nodeEndOffset = accumulatedOffset + s.length;
     
     if (nodeEndOffset >= offset)
     {
     if (splitOffset) {
     *splitOffset = (offset - accumulatedOffset);
     }
     return node;
     }
     accumulatedOffset = nodeEndOffset;
     }
     node = node.nextNode;
     }
     
     return nil;
     */
}

- (MPTextContentOffset)textContentOffsetForInnerXMLElementAtXPath:(NSString *)XPath
                                                textContentOffset:(MPTextContentOffset)innerOffset
                                                            error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(innerOffset >= 0);
    
    [self enforceExplicitPreservedSpace];
    
    NSXMLElement *innerElement = nil;
    if (![self innerXMLElement:&innerElement atXPath:XPath error:error]) {
        return MPTextContentOffsetError;
    }
    if (!innerElement) {
        return MPTextContentOffsetNotFound;
    }
    
    MPTextContentOffset offset = [self textContentOffsetForInnerXMLElement:innerElement textContentOffset:innerOffset];
    return offset;
}

- (MPTextContentOffset)textContentOffsetForInnerXMLElement:(NSXMLElement *)innerElement
                                         textContentOffset:(MPTextContentOffset)outerOffset
{
    [self enforceExplicitPreservedSpace];
    
    if (innerElement == self) {
        return outerOffset;
    }
    
    __block MPTextContentOffset accumulatedOffset = 0;
    
    [self visitAllNodesInSubtree:^BOOL(NSXMLNode * _Nonnull node)
     {
         if (node == innerElement)
         {
             NSString *s = node.stringValue;
             NSUInteger l = s.length;
             
             if (outerOffset == MPTextContentOffsetEnd) {
                 accumulatedOffset += l;
             } else {
                 accumulatedOffset += MIN(l, accumulatedOffset - outerOffset);
             }
             
             return NO; // We're done here
         }
         else if (node.kind == NSXMLTextKind)
         {
             accumulatedOffset += [node stringValue].length;
         }
         
         return YES; // Continue until encountering given inner element
     }];
    
    return accumulatedOffset;
}

/*
 - (MPTextContentOffset)textContentOffsetForInnerXMLElement:(NSXMLElement *)innerElement
 textContentOffset:(MPTextContentOffset)offset
 {
 if (innerElement == self) {
 return offset;
 }
 
 __block MPTextContentOffset accumulatedOffset = 0;
 
 [self enumerateTextNodeValuesIncludingPreservedSpaceVisitElementsAtLeastOnce:YES
 withEnumerator:^BOOL(NSXMLNode *node, NSString *stringValue)
 {
 if (node == innerElement)
 {
 if (offset > 0)
 {
 NSString *s = node.stringValue;
 NSUInteger l = s.length;
 
 if (offset == MPTextContentOffsetEnd) {
 accumulatedOffset += l;
 } else {
 accumulatedOffset += offset;
 }
 }
 MPLogDebug(@"*Final* accumulated offset %@ after '%@'", @(accumulatedOffset), node.stringValue);
 MPAssertTrue(accumulatedOffset >= [self _textContentOffsetForInnerXMLElement:innerElement textContentOffset:offset]);
 return NO;
 }
 else // if (node.kind == NSXMLTextKind)
 {
 accumulatedOffset += stringValue.length;
 MPLogDebug(@"Accumulated offset %@ after '%@'", @(accumulatedOffset), node.stringValue);
 return YES;
 }
 }];
 
 //MPLogDebug(@"Text content offset %li within inner XML element:\n%@\nof XML element:\n%@\nis... %li", offset, innerElement.prettyXMLString, self.prettyXMLString, accumulatedOffset);
 //MPLogDebug(@"That means '%@' should end with '%@'", [self.stringValue substringToIndex:accumulatedOffset], innerElement.stringValue);
 
 return accumulatedOffset;
 }
 */

- (NSUInteger)removeChild:(NSXMLNode *)node
{
    NSUInteger i = [self.children indexOfObject:node];
    if (i != NSNotFound) {
        [self removeChildAtIndex:i];
    }
    return i;
}

- (NSUInteger)replaceChild:(NSXMLNode *)node withNode:(NSXMLNode *)replacingNode
{
    NSUInteger i = [self.children indexOfObject:node];
    if (i != NSNotFound)
    {
        [self removeChildAtIndex:i];
        [replacingNode detach];
        [self insertChild:replacingNode atIndex:i];
    }
    return i;
}

- (NSUInteger)replaceChild:(NSXMLNode *)node withNodes:(NSArray *)nodes
{
    NSUInteger i = [self.children indexOfObject:node];
    if (i != NSNotFound)
    {
        [self removeChildAtIndex:i];
        
        for (NSUInteger j = 0; j < nodes.count; j++)
        {
            NSXMLNode *n = nodes[j];
            [n detach];
            [self insertChild:n atIndex:(i + j)];
        }
    }
    return i;
}

- (NSArray *)splitAtInnerXMLElementXPath:(NSString *)XPath textContentOffset:(MPTextContentOffset)innerElementOffset error:(NSError *__autoreleasing  _Nullable *)error
{
    NSParameterAssert(innerElementOffset >= MPTextContentOffsetBeginning);
    
    // Prepare
    [self normalizeAdjacentTextNodesPreservingCDATA:NO];
    [self enforceExplicitPreservedSpace];
    
    // Find text node to split
    NSXMLElement *splitAnchorElement = nil;
    
    if (!XPath || [XPath isEqualToString:@"."]) {
        splitAnchorElement = self;
    }
    else
    {
        if (![self innerXMLElement:&splitAnchorElement atXPath:XPath error:error]) {
            return nil;
        }
        if (!splitAnchorElement)
        {
            if (error) {
                *error = [NSError errorWithDomain:MPXMLElementErrorDomain code:MPXMLElementErrorCodeInnerXMLElementNotFound description:MPStringWithFormat(@"Failed to find inner XML element '%@' to split at", XPath)];
            }
            return nil;
        }
    }
    
    MPTextContentOffset splitOffset = NSNotFound;
    NSXMLNode *textNodeToSplit = [splitAnchorElement textNodeAtOffset:innerElementOffset offsetWithinTextNode:&splitOffset];
    if (!textNodeToSplit)
    {
        if (error) {
            *error = [NSError errorWithDomain:MPXMLElementErrorDomain code:MPXMLElementErrorCodeInnerXMLElementNotFound userInfo:@{NSLocalizedDescriptionKey:MPStringWithFormat(@"Failed to find text node to split at offset %lu", innerElementOffset)}];
        }
        return nil;
    }
    
    // Gather nodes before and after split
    NSMutableArray *headNodes = [NSMutableArray new], *tailNodes = [NSMutableArray new];
    __block BOOL beforeSplit = YES;
    
    [self visitAllNodesInSubtree:^BOOL(NSXMLNode * _Nonnull node)
     {
         if (beforeSplit) {
             [headNodes addObject:node];
         }
         else {
             [tailNodes addObject:node];
         }
         
         if (node == textNodeToSplit)
         {
             // At this stage, the text node to split and it's ancestry count as *both* head *and* tail
             NSXMLNode *n = node;
             while (n && n != self)
             {
                 [tailNodes addObject:n];
                 n = n.parent;
             }
             
             beforeSplit = NO;
         }
         
         return YES;
     }];
    
    [headNodes insertObject:self atIndex:0];
    [tailNodes addObject: self];
    
    // Recreate head and tail hierarchies
    NSXMLElement *headElement = [self _recreateSplitSubtree:headNodes textNodeToSplit:textNodeToSplit splitOffset:splitOffset isHead:YES];
    NSXMLElement *tailElement = [self _recreateSplitSubtree:tailNodes textNodeToSplit:textNodeToSplit splitOffset:splitOffset isHead:NO];
    
    return @[headElement, tailElement];
}

/**
 
 This private method is ONLY to be called by `splitAtInnerXMLElementXPath:textContentOffset:error:`, it has zero generic use!
 
 If you fiddle with `splitAtInnerXMLElementXPath:...`, it is crucial to _keep the order of sibling nodes_ when passing in the `originalNodes` argument here (which `visitAllNodesInSubtree:` does do).
 
 */
- (NSXMLElement *)_recreateSplitSubtree:(NSArray *)originalNodes textNodeToSplit:(NSXMLNode *)textNodeToSplit splitOffset:(MPTextContentOffset)splitOffset isHead:(BOOL)isHead
{
    NSMutableArray *newNodes = [NSMutableArray new];
    NSXMLElement *newRootElement = nil;
    
    // Recreate nodes
    for (NSXMLNode *node in originalNodes)
    {
        // Elements
        if (node.kind == NSXMLElementKind)
        {
            NSXMLElement *el = [NSXMLElement elementWithName:node.name];
            [el setAttributesFromElement:(NSXMLElement *)node];
            [newNodes addObject:el];
            
            if (node == self) {
                newRootElement = el;
            }
        }
        
        // Text nodes
        else if (node.kind == NSXMLTextKind)
        {
            NSString *s = node.stringValue;
            
            if (node == textNodeToSplit)
            {
                if (isHead) {
                    s = [s substringToIndex:splitOffset];
                }
                else {
                    s = [s substringFromIndex:splitOffset];
                }
            }
            
            NSXMLNode *t = [NSXMLNode textWithStringValue:s];
            [newNodes addObject:t];
        }
    }
    
    // Recreate hierarchy
    for (NSUInteger i = 0; i < originalNodes.count; i++)
    {
        NSXMLNode *originalNode = (NSXMLNode *)originalNodes[i];
        NSXMLElement *originalParent = (NSXMLElement *)[originalNode parent];
        NSUInteger parentIndex = [originalNodes indexOfObject:originalParent];
        NSParameterAssert(parentIndex != NSNotFound || originalNode == self);
        
        if (originalNode != self)
        {
            NSXMLElement *newParent = (NSXMLElement *)newNodes[parentIndex];
            NSParameterAssert(newParent);
            [newParent addChild:newNodes[i]];
        }
    }
    
    [newRootElement normalizeAdjacentTextNodesPreservingCDATA:NO];
    [newRootElement enforceExplicitPreservedSpace];
    
    return newRootElement;
}

- (BOOL)isChild:(NSXMLNode *)node
{
    return [self.children containsObject:node];
}

- (BOOL)isDescendant:(NSXMLNode *)node
{
    while (node)
    {
        if (node == self) {
            return YES;
        }
        node = node.parent;
    }
    return NO;
}

- (NSXMLElement *)XMLElementByFilteringAttributes:(MPXMLNodeFilter)attributeFilter
                                         children:(MPXMLNodeFilter)childFilter
{
    NSXMLElement *newElement = [NSXMLElement elementWithName:self.name];
    NSMutableArray *newElementStack = [NSMutableArray arrayWithObject:newElement]; ///, *elementStack = [NSMutableArray arrayWithObject:self];
    NSXMLNode *node = [self.children firstObject], *previousNode = self;
    
    /**
     NSMutableArray *existingElementStack = [NSMutableArray arrayWithObject:self];
     NSXMLNode *node = self.nextNode, *previousNode = self;
     
     while (node && node.level > self.level && node != textNodeToSplit)
     {
     if (node.kind == NSXMLElementKind)
     {
     if (node.level >= previousNode.level)
     {
     if (node.level == previousNode.level && previousNode.kind == NSXMLElementKind) {
     [existingElementStack popObject];
     }
     [existingElementStack pushObject:node];
     }
     else
     {
     [existingElementStack popObject];
     }
     }
     node = node.nextNode;
     }
     */
    
    while (node && node.level > self.level)
    {
        if (!(node.kind == NSXMLElementKind || node.kind == NSXMLTextKind)) {
            continue; // TODO: add support for other node kinds, if needed
        }
        
        MPXMLNodeFilteringResult result = childFilter(node);
        BOOL didPickNextNode = NO;
        
        if (result == MPXMLNodeFilteringResultKeep)
        {
            NSXMLNode *newNode = [[NSXMLNode alloc] initWithKind:node.kind options:0];
            [newElementStack.firstObject addChild:newNode];
            
            if (node.kind == NSXMLElementKind)
            {
                [newElementStack pushObject:newNode];
                
                NSArray *attributes = [(NSXMLElement *)node attributes];
                
                if (attributeFilter && attributes.count > 0)
                {
                    attributes = [attributes filteredArrayMatching:^BOOL(NSXMLNode *attribute)
                                  {
                                      return (attributeFilter(attribute) == MPXMLNodeFilteringResultKeep);
                                  }];
                }
                
                if (attributes.count > 0)
                {
                    attributes = [attributes mapObjectsUsingBlock:^id(id attribute, NSUInteger i)
                                  {
                                      return [NSXMLNode attributeWithName:[attribute name] stringValue:[attribute stringValue]];
                                  }];
                    ((NSXMLElement *)newNode).attributes = attributes;
                }
                
                newNode.name = node.name;
            }
            else if (node.kind == NSXMLTextKind) {
                newNode.stringValue = [node.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            }
        }
        else if (result == MPXMLNodeFilteringResultRemove)
        {
            // Iterate over element contents
            if (node.kind == NSXMLElementKind)
            {
                NSXMLNode *innerNode = node.nextNode;
                
                while (innerNode && innerNode.level > node.level)
                {
                    innerNode = innerNode.nextNode;
                }
                
                node = innerNode.nextNode;
                didPickNextNode = YES;
            }
        }
        else if (result == MPXMLNodeFilteringResultCollapse) {
            NSParameterAssert(node.kind == NSXMLElementKind);
        }
        
        previousNode = node;
        
        if (!didPickNextNode) {
            node = node.nextNode;
        }
        
        // Descend if appropriate
        NSUInteger elementDepth = 0;
        NSXMLNode *n = node;
        while (n.level > self.level)
        {
            elementDepth++;
            n = n.parent;
        }
        while (newElementStack.count > elementDepth) {
            [newElementStack popObject];
        }
    }
    
    //MPLogDebug(@"Filtering %@ yielded: %@", self.prettyXMLString, newElement.prettyXMLString);
    
    [newElement normalizeAdjacentTextNodesPreservingCDATA:NO];
    return newElement;
}

- (NSXMLElement *)XMLElementByFilteringDescendantElements:(NSArray *)allowedElementNames
                                               attributes:(NSArray *)allowedAttributeNames
{
    NSXMLElement *newElement = [self XMLElementByFilteringAttributes:^MPXMLNodeFilteringResult(NSXMLNode *node)
                                {
                                    if (!allowedAttributeNames) {
                                        return MPXMLNodeFilteringResultKeep;
                                    }
                                    if ([allowedAttributeNames containsObject:node.name]) {
                                        return MPXMLNodeFilteringResultKeep;
                                    }
                                    
                                    for (NSString *s in allowedAttributeNames)
                                    {
                                        if ([s containsSubstring:@"#"] && [[s substringBefore:@"#"] isEqualToString:node.parent.name])
                                        {
                                            NSString *t = [s substringAfter:@"#"];
                                            if ([t isEqualToString:node.name] || [t isEqualToString:@"*"]) {
                                                return MPXMLNodeFilteringResultKeep;
                                            }
                                        }
                                    }
                                    
                                    return MPXMLNodeFilteringResultRemove;
                                }
                                                            children:^MPXMLNodeFilteringResult(NSXMLNode *node)
                                {
                                    if (node.kind == NSXMLTextKind) {
                                        return MPXMLNodeFilteringResultKeep;
                                    }
                                    else if (node.kind == NSXMLElementKind)
                                    {
                                        if ([allowedElementNames containsObject:node.name.lowercaseString]) {
                                            return MPXMLNodeFilteringResultKeep;
                                        }
                                        return MPXMLNodeFilteringResultCollapse;
                                    }
                                    return MPXMLNodeFilteringResultRemove;
                                }];
    return newElement;
}

@end


@implementation NSString (MPXMLExtensions)

- (NSString *)innerXMLString
{
    NSXMLElement *XML = [NSXMLElement XMLElementFromString:self error:nil];
    NSString *inner = [XML innerXMLString];
    return inner;
}

- (NSString *)prettyXMLString
{
    NSXMLElement *XML = [NSXMLElement XMLElementFromString:self error:nil];
    NSString *pretty = [XML prettyXMLString];
    return pretty;
}

+ (NSCharacterSet *)invalidUTF8EncodedXMLCharacters
{
    /*
     
     Wikipedia says:
     
     Unicode code points in the following ranges are valid in XML 1.0 documents:
     
     U+0009, U+000A, U+000D: these are the only C0 controls accepted in XML 1.0;
     U+0020–U+D7FF, U+E000–U+FFFD: this excludes some (not all) non-characters in the BMP (all surrogates, U+FFFE and U+FFFF are forbidden);
     U+10000–U+10FFFF: this includes all code points in supplementary planes, including non-characters.
     
     The preceding code points ranges contain the following controls which are only valid in certain contexts in XML 1.0 documents, and whose usage is restricted and highly discouraged:
     
     U+007F–U+0084, U+0086–U+009F: this includes a C0 control character and all but one C1 control.
     
     */
    static dispatch_once_t token = 0;
    static NSCharacterSet *invalidCharacters = nil;
    
    dispatch_once(&token, ^
                  {
                      NSMutableCharacterSet *characters = [NSMutableCharacterSet new];
                      
                      // Add ranges of valid-in-XML-1.0 characters
                      [characters addCharactersInRange:NSMakeRange(0x0009, 1)];
                      [characters addCharactersInRange:NSMakeRange(0x000A, 1)];
                      [characters addCharactersInRange:NSMakeRange(0x000D, 1)];
                      [characters addCharactersInRange:NSMakeRange(0x0020, 0xD7FF - 0x0020 + 1)];
                      [characters addCharactersInRange:NSMakeRange(0xE000, 0xFFFD - 0xE000 + 1)];
                      [characters addCharactersInRange:NSMakeRange(0x10000, 0x10FFFF - 0x10000 + 1)];
                      
                      // Remove ranges of "highly discouraged" characters
                      [characters removeCharactersInRange:NSMakeRange(0x007F, 0x0084 - 0x007F + 1)];
                      [characters removeCharactersInRange:NSMakeRange(0x0086, 0x009F - 0x0086 + 1)];
                      
                      // Union inverse with illegal UTF-8 characters
                      [characters invert];
                      [characters formIntersectionWithCharacterSet:[NSCharacterSet unicodeGremlinCharacterSet]];
                      
                      invalidCharacters = [characters copy];
                  });
    
    return invalidCharacters;
}

- (NSString *)stringByEscapingUnescapedAmpersands
{
    if ([self rangeOfString:@"&"].location == NSNotFound) {
        return self;
    }
    
    static NSArray *entities = nil;
    if (!entities) {
        entities = @[@"&amp;", @"&quot;", @"&apos;", @"&lt;", @"&gt;"];
    }
    
    NSMutableString *ms = [NSMutableString stringWithString:self];
    NSRange r = NSMakeRange(0, ms.length);
    
    do
    {
        r = [ms rangeOfString:@"&" options:0 range:r];
        
        if (r.location != NSNotFound)
        {
            BOOL shouldEscape = YES;
            
            // Look for one of the standard XML entities
            for (NSString *entity in entities)
            {
                if (r.location + entity.length > ms.length) {
                    continue;
                }
                
                if ([[ms substringWithRange:NSMakeRange(r.location, entity.length)] isEqualToString:entity])
                {
                    shouldEscape = NO;
                    break;
                }
            }
            
            // Look for a numeric character entity (of either decimal form &#nnnn; or in hex &#xhhhh;)
            if (shouldEscape && (ms.length > r.location + 2) && ([ms characterAtIndex:(r.location + 1)] == '#'))
            {
                static NSCharacterSet *decimalEntityCharacters = nil, *hexEntityCharacters = nil;
                if (!decimalEntityCharacters)
                {
                    decimalEntityCharacters = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
                    hexEntityCharacters = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
                }
                
                BOOL isHex = ([ms characterAtIndex:r.location + 2] == 'x');
                NSCharacterSet *entityCharacters = isHex ? hexEntityCharacters : decimalEntityCharacters;
                NSUInteger entityCharacterCount = 0;
                
                for (NSUInteger i = r.location + (isHex ? 3 : 2); i < ms.length; i++)
                {
                    unichar c = [ms characterAtIndex:i];
                    
                    if ([entityCharacters characterIsMember:c]) {
                        entityCharacterCount++;
                    }
                    else if (c == ';' && entityCharacterCount > 0)
                    {
                        shouldEscape = NO;
                        break;
                    }
                    else {
                        break;
                    }
                }
            }
            
            if (shouldEscape) {
                [ms replaceCharactersInRange:r withString:@"&amp;"];
            }
            
            r = [ms rangeOfString:@"&" options:0 range:NSMakeRange(r.location + 1, ms.length - (r.location + 1))];
        }
    }
    while (r.location != NSNotFound && r.location < ms.length);
    
    return [ms copy];
}

- (NSString *)stringByEscapingAsXMLAttributeValue
{
    NSString *s = [self stringByEscapingAsXMLTextContent];
    s = [s stringByReplacingOccurrencesOfString:@"\"" withString:@"&quot;"];
    s = [s stringByReplacingOccurrencesOfString:@"'" withString:@"&apos;"];
    return s;
}

- (NSString *)stringByEscapingAsXMLTextContent
{
    NSString *s = [self stringByEscapingUnescapedAmpersands]; // TODO: would make sense to avoid double-espacing of & that is already the start marker of an entity
    s = [s stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
    s = [s stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
    return s;
}

- (BOOL)appearsToContainSerialisedXML
{
    if (self.length > 1 && (([self containsString:@"<"]  && [self containsString:@">"]) || ([self containsString:@"&"] && [self containsString:@";"]))) {
        return YES;
    }
    return NO;
}

/*
 - (NSString *)stringByNormalizingNewlineCharacters
 {
 MPLogDebug(@"Will normalize newlines in: %@", [self stringWithCodesForNonAlphanumericCharacters]);
 
 static NSCharacterSet *UnicodeNewlines = nil;
 if (!UnicodeNewlines)
 {
 //
 // From https://en.wikipedia.org/wiki/Newline#Unicode
 //
 // NEL:   Next Line, U+0085
 // LS:    Line Separator, U+2028
 // PS:    Paragraph Separator, U+2029
 //
 NSMutableCharacterSet *mcs = [NSMutableCharacterSet new];
 [mcs addCharactersInRange:NSMakeRange(0x0085, 1)];
 [mcs addCharactersInRange:NSMakeRange(0x2028, 2)];
 UnicodeNewlines = [mcs copy];
 }
 
 NSRange r = [self rangeOfCharacterFromSet:UnicodeNewlines];
 
 if (r.length > 0)
 {
 NSMutableString *ms = [NSMutableString stringWithString:self];
 [ms replaceCharactersInSet:UnicodeNewlines withString:@"\n"];
 }
 
 return self;
 }*/

- (NSString *)stringWithCodesForNonAlphanumericCharacters
{
    NSMutableString *ms = [NSMutableString new];
    
    for (NSUInteger i = 0; i < self.length; i++)
    {
        unichar c = [self characterAtIndex:i];
        if ([[NSCharacterSet alphanumericCharacterSet] characterIsMember:c] ||
            [[NSCharacterSet punctuationCharacterSet] characterIsMember:c] ||
            [[NSCharacterSet whitespaceCharacterSet] characterIsMember:c]
            ) {
            [ms appendFormat:@"%c", c];
        }
        else {
            [ms appendFormat:@"<%lu>", (NSUInteger)c];
        }
    }
    
    return [ms copy];
}

- (NSString *)stringByRemovingInvalidUTF8EncodedXMLCharacters
{
    // TODO: move these two lines to a separate cleanup method
    NSString *s = [self stringByReplacingOccurrencesOfString:@"svg xmlns:xlink=\"http://www.w3.org/1999/xlink " withString:@"svg xmlns:xlink=\"http://www.w3.org/1999/xlink\" "];
    s = [s stringByReplacingOccurrencesOfString:@"xmlns=\"http://www.w3.org/2000/svg " withString:@"xmlns=\"http://www.w3.org/2000/svg\" "];
    
    NSCharacterSet *invalidCharacters = [NSString invalidUTF8EncodedXMLCharacters];
    NSRange r = [s rangeOfCharacterFromSet:invalidCharacters];
    
    if (r.length > 0)
    {
        NSLog(@"Input XML string contains characters invalid in UTF-8-encoded XML at %@:\n%@", NSStringFromRange(r), s);
        
        NSMutableString *ms = [NSMutableString stringWithString:s];
        [ms removeCharactersInSet:invalidCharacters];
        return [ms copy];
    }
    
    return s;
}

@end


@implementation NSXMLDocument (MPXMLExtensions)

+ (NSXMLDocument *)XMLDocumentFromString:(NSString *)XMLString options:(NSUInteger)options error:(NSError *__autoreleasing *)error
{
    NSString *cleanXMLString = [XMLString stringByRemovingInvalidUTF8EncodedXMLCharacters];
    NSXMLDocument *document = [[NSXMLDocument alloc] initWithXMLString:cleanXMLString options:options error:error];
    document.documentContentKind = NSXMLDocumentXMLKind;
    return document;
}

- (NSUInteger)exterminateDocTypeAndNamespaces
{
    NSUInteger namespacedItemsEncountered = 0;
    // Remove any and all namespaces elements may have set; they will break normalize_html.xsl's operation
    NSMutableArray *queue = [NSMutableArray arrayWithObject:self.rootElement];
    while (queue.count > 0)
    {
        NSXMLElement *element = [queue popObject];
        if ([element namespaces].count > 0) {
            [element setNamespaces:nil];
            namespacedItemsEncountered++;
        }
        
        NSUInteger i = 0;
        for (NSXMLNode *n in element.children)
        {
            if ([n isKindOfClass:NSXMLElement.class]) {
                [queue insertObject:n atIndex:i];
                i++;
            }
        }
    }
    
    self.documentContentKind = NSXMLDocumentXMLKind;
    [self setRootElement:[self.rootElement _recreateClean]];
    [self setStandalone:YES];
    
    return namespacedItemsEncountered;
}

@end
