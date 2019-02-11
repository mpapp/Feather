//
//  MPExtensions.h
//  Manuscripts
//
//  Created by Matias Piipari on 29/06/2014.
//  Copyright (c) 2014-2015 Manuscripts.app Limited. All rights reserved.
//


#import <Foundation/Foundation.h>


typedef NSInteger MPTextContentOffset;

extern const MPTextContentOffset MPTextContentOffsetError;
extern const MPTextContentOffset MPTextContentOffsetNotFound;
extern const MPTextContentOffset MPTextContentOffsetBeginning;
extern const MPTextContentOffset MPTextContentOffsetEnd;

extern const NSXMLNodeOptions MPDefaultXMLDocumentParsingOptions;
extern const NSXMLNodeOptions MPDefaultXMLDocumentOutputOptions;

typedef NS_ENUM(NSInteger, MPXMLNodeFilteringResult)
{
    MPXMLNodeFilteringResultKeep = 1,
    MPXMLNodeFilteringResultCollapse = 0,
    MPXMLNodeFilteringResultRemove = -1
};

typedef MPXMLNodeFilteringResult (^MPXMLNodeFilter)(NSXMLNode *__nonnull node);

typedef BOOL (^MPFirstMatchingXMLElementTest)(NSXMLElement *__nonnull element);
typedef BOOL (^MPMatchingXMLElementsTest)(NSXMLElement *__nonnull element, BOOL *__nullable stop);

typedef BOOL (^MPXMLNodeVisitor)(NSXMLNode *__nonnull node);


@interface NSXMLElement (MPExtensions)

//
// String representation shorthands
//
#pragma mark -

/**
 
 Parse a string into an XML element, tidying the string as an HTML fragment.
 
 You should call this method instead of the plainer, simpler `XMLElementFromString:error:` in cases where it is important to handle whitespace in the specific way that makes sense for HTML content. In other words, any operations that *process* an HTML fragment originally in persisted string form, must use this method, never mind the relative inconvenience documented below.
 
 This implementation filters out invalid characters not allowed by the XML 1.0 specification, as well as sequences that aren't valid UTF-8, prior to parsing the input string.
 
 @param document out pointer for storing a reference to the `NSXMLDocument` instance created as a result of parsing and tidying. IMPORTANT: if you plan to evaluate XPath expressions against the returned XML element, you must also hold onto the document object as long as that task is needed to be done — otherwise XPath expressions will usually return zero results.
 
 */
+ (nullable NSXMLElement *)XMLElementFromHTMLString:(nonnull NSString *)HTML
                                       tidyDocument:(out NSXMLDocument *__autoreleasing __nullable *__nullable)document
                                              error:(NSError *__nullable __autoreleasing *__nullable)error;

/** Parse a string into XML and return the root element of the fragment, plus any inner elements matching given optional XPath expressions. Returned inner elements array will contain the results in the same order as the `XPaths` argument. */
+ (nullable NSXMLElement *)XMLElementFromHTMLString:(nonnull NSString *)HTML
                                      innerElements:(out NSArray<NSXMLElement *> *__nonnull __autoreleasing* __nullable)innerElements
                                          forXPaths:(nullable NSArray<NSString *>*)XPaths
                                              error:(out NSError *__nullable __autoreleasing * __nullable)error;

/** Parse an XML string into an XML element. This implementation filters out invalid characters not allowed by the XML 1.0 specification, as well as sequences that aren't valid UTF-8, prior to parsing the input string. */
+ (nullable NSXMLElement *)XMLElementFromString:(nonnull NSString *)XMLString error:(NSError *__nullable __autoreleasing * __nullable)error;

/** The contents of the element without the tag opening & closing */
- (nonnull NSString *)innerXMLString;

- (BOOL)normalizeWhitespaceWithinDescendantElementsNamed:(nonnull NSArray<NSString *> *)elementNames error:(NSError *_Nullable *_Nullable)error;

/** Pretty-printed outer XML string representation of this XML element. */
- (nonnull NSString *)prettyXMLString;

/** Return combined length of text nodes in this XML element's subtree. */
- (NSUInteger)textContentLength;

/** Parse given string as XML and return its combined text content. In other words, convert XML string to plain text. */
+ (nullable NSString *)textContentForXMLString:(nonnull NSString *)XMLString
                                         error:(NSError *__nullable *__nullable)error;

+ (NSUInteger)textContentLengthForXMLString:(nonnull NSString *)XMLString
                                      error:(NSError *__nullable *__nullable)error;

+ (MPTextContentOffset)textContentOffsetForXMLString:(nonnull NSString *)XMLString
                                   innerElementXPath:(nonnull NSString *)XPath
                                         innerOffset:(MPTextContentOffset)innerOffset
                                               error:(NSError *__nullable *__nullable)error;

/**
 
 Return combined length of text nodes in this XML element's subtree *up to, excluding* given descendant node.
 
 Will return `NSNotFound` if the anchor node isn't actually encountered.
 
 */
- (NSUInteger)textContentLengthBeforeNode:(nonnull NSXMLNode *)anchorNode;

/** Return `YES` if given node is a direct child of this XML element, `NO` if not. */
- (BOOL)isChild:(nonnull NSXMLNode *)node;

/** Return `YES` if given node is contained by this XML element, `NO` if not. */
- (BOOL)isDescendant:(nonnull NSXMLNode *)node;

//
// HTML class attribute helpers
//
#pragma mark -

/**
 Add a given string to this XML element's `class` attribute, creating it if it doesn't exist yet.
 @return YES if string was added, NO if it was already there
 */
- (BOOL)addClass:(nonnull NSString *)klass;

/** Check whether this XML element contains the given string as a whitespace-separated value in the `class` attribute. */
- (BOOL)hasClass:(nonnull NSString *)klass;

/** Check if this XML element has a nonnil & nonempty `id` attribute value. */
- (BOOL)hasID;

/**
 Remove given string from this XML element's `class` attribute.
 @return YES if given class string was removed, NO if not (because it wasn't there in the first place).
 */
- (BOOL)removeClass:(nonnull NSString *)klass;

- (void)setAttributeNamed:(nonnull NSString *)attributeName stringValue:(nonnull NSString *)value;

- (void)setAttributesFromElement:(nonnull NSXMLElement *)sourceElement;

//
// Searches
//

- (nonnull NSArray<NSXMLElement *>*)childElements;

/** Traverse element subtree of this element and return first matching element. */
- (nullable NSXMLElement *)findXMLElementMatching:(_Nonnull MPFirstMatchingXMLElementTest)test;

/** Find first element in subtree matching given element name, id and other attribute values, and having a given class (as determined by calling `hasClass:`. Provide `nil` for any argument to indicate its value (or absence of one) does not matter. */
- (nullable NSXMLElement *)findXMLElementByName:(nullable NSString *)elementName
                                             ID:(nullable NSString *)ID
                                          class:(nullable NSString *)klass
                                attributeValues:(nullable NSDictionary *)attributeValues;

- (nullable NSXMLElement *)findXMLElementByName:(nonnull NSString *)elementName;
- (nullable NSArray<NSXMLElement *> *)findXMLElementsByNames:(nonnull NSArray<NSString *>*)elementNames;
- (nullable NSArray<NSXMLElement *> *)findXMLElementsByClass:(nonnull NSString *)hasClass;
- (nullable NSXMLElement *)findXMLElementByID:(nonnull NSString *)elementID;
- (nullable NSXMLElement *)findXMLElementByClass:(nonnull NSString *)hasClass;
- (nullable NSXMLElement *)findXMLElementByAttributeValues:(nonnull NSDictionary<NSString *, NSString *>*)attributeValues;

/** Traverse element subtree of this element and return elements passing given test, until (optionally) stopped. */
- (nullable NSArray<NSXMLElement *> *)findXMLElementsPassing:(_Nonnull MPMatchingXMLElementsTest)test;

- (nullable NSXMLElement *)previousElementSibling;
- (nullable NSXMLElement *)nextElementSibling;

- (BOOL)containsDescendantNode:(nonnull NSXMLNode *)node;
+ (nullable NSXMLElement *)commonAncestorElementOf:(nonnull NSXMLElement *)firstElement and:(nonnull NSXMLElement *)secondElement;

- (NSUInteger)visitAllNodesInSubtree:(_Nonnull MPXMLNodeVisitor)visitor;
- (NSUInteger)visitNodesInSubtreeStartingFrom:(nonnull NSXMLNode *)startNode visitor:(_Nonnull MPXMLNodeVisitor)visitor;

//
// Element structure manipulations
//
#pragma mark -

/** Replace this XML element by its children nodes. */
- (void)collapse;

/**
 
 Wrap given nodes in a new containing element, inserted at the current position of the first child node.
 
 Any nodes that are not direct children of this element will be ignored. If *none* of the nodes are, this method does nothing.
 
 Note that generally you will probably want to avoid weird effects, and only call this method on a contiguous slice of child nodes.
 That however is *not* checked by this method, so you *can* group any children together in a new container if you happen to have
 such a use case at hand.
 
 @return The wrapping element that was created, or `nil` if nothing was done.
 
 */
- (nullable NSXMLElement *)wrapChildren:(nonnull NSArray *)nodes elementName:(nonnull NSString *)wrappingElementName;

/** Starting at beginning of a given ancestor element, delete text nodes up to given offset *within this element* and split text node at given offset, deleting the leading part. */
- (NSUInteger)deleteTextUpToOffset:(MPTextContentOffset)offset
    fromBeginningOfAncestorElement:(nullable NSXMLElement *)rootElement NS_SWIFT_NAME(deleteText(upToOffset:fromBeginningOfAncestor:));

/** Starting at the given offset *within this elemenet* delete text nodes up to the end of a given ancestor element, and split the text node at given offset, deleting the trailing part. */
- (NSUInteger)deleteTextFromOffset:(MPTextContentOffset)offset
            toEndOfAncestorElement:(nullable NSXMLElement *)rootElement NS_SWIFT_NAME(deleteText(fromOffset:toEndOfAncestor:));

/** Evaluate given XPath relative to this XML element, and return (via the out argument) the resulting XML element from this XML element's subtree, or `nil` if XPath yields no such result. Returns `YES` if there was no error, `NO` if an error occurred. */
- (BOOL)innerXMLElement:(out NSXMLElement *__nullable * __nullable)innerElement
                atXPath:(nonnull NSString *)XPath
                  error:(NSError *__nullable __autoreleasing * __nullable)error;

/** Convert, in-place, any and all elements with implicit preserved space, in the vein of ' <b>bold</b>' or '<i>italic</i> ', to explicit text nodes for the space instead. */
- (void)enforceExplicitPreservedSpace;

/** Normalize whitespace and newline characters in contained text node contents, in-place. Explicit preserved space text nodes are also enforced. */
- (void)normalizeWhitespaceAllowLeading:(BOOL)allowLeadingWhitespace trailing:(BOOL)allowTrailingWhitespace NS_SWIFT_NAME(normalizeWhitespace(allowLeading:trailing:));

/** Replace given child node with another one. Return the index where the node was at, or `NSNotFound`. */
- (NSUInteger)removeChild:(nonnull NSXMLNode *)node;

/** Replace given child node with a new node. Returns the index where the child node was at, or `NSNotFound`. */
- (NSUInteger)replaceChild:(nonnull NSXMLNode *)node withNode:(nonnull NSXMLNode *)replacingNode;

/** Replace given child node with an array of new nodes. Return the index where the node was at, or `NSNotFound`. */
- (NSUInteger)replaceChild:(nonnull NSXMLNode *)node withNodes:(nonnull NSArray<NSXMLNode *> *)nodes;

/**
 
 Split this XML element in half at given text offset, relative to an XML element contained in this element's subtree, and a text content offset within that contained XML element.
 
 @return Two-element array containing newly constructed head and tail XML elements, representing XML hierarchy before and after the given split location.
 
 */
- (nullable NSArray<NSXMLElement *> *)splitAtInnerXMLElementXPath:(nonnull NSString *)XPath
                                                textContentOffset:(MPTextContentOffset)innerOffset
                                                            error:(NSError *__nullable *__nullable)error;

/** Return text content offset within this XML element*/
- (MPTextContentOffset)textContentOffsetForInnerXMLElement:(nonnull NSXMLElement *)innerElement
                                         textContentOffset:(MPTextContentOffset)offset;

- (MPTextContentOffset)textContentOffsetForInnerXMLElementAtXPath:(nonnull NSString *)XPath
                                                textContentOffset:(MPTextContentOffset)offset
                                                            error:(NSError *__nullable *__nullable)error;

- (nonnull NSXMLElement *)XMLElementByFilteringAttributes:(_Nonnull MPXMLNodeFilter)attributeFilter
                                                 children:(_Nonnull MPXMLNodeFilter)childFilter;

/**
 
 Return a new XML element otherwise identical to this one, but with all descendant elements with an element name _not_ on the allowed list recursively collapsed to their inner nodes.
 
 @param allowedElementNames Allowed element names (required).
 @param allowedAttributeNames Optionally, also filter attributes by name and/or parent element name. This argument can have two types of strings in it:
 
 - @"name": interpreted as an attribute name to allow on any parent element
 - @"elementName#attributeName": interpreted as an attribute to allow on specific types of element
 
 If this argument is `nil`, all attribute nodes encountered are cloned.
 
 */
- (nonnull NSXMLElement *)XMLElementByFilteringDescendantElements:(nonnull NSArray<NSString *>*)allowedElementNames attributes:(nullable NSArray<NSString *> *)allowedAttributeNames;

@end


@interface NSString (MPXMLExtensions)

/** First parsing this string into an NSXMLElement, return the contents of the element without the opening and closing tags, or `nil` if this string cannot be parsed into an XML element. */
- (nullable NSString *)innerXMLString;

/** First parsing this string into an NSXMLElement, return a pretty-printed outer XML string representation, or `nil` if this string cannot be parsed into an XML element. */
- (nullable NSString *)prettyXMLString;

/** If this string contains any characters that are invalid either in XML 1.0 or UTF-8, return a new string with such characters removed. Otherwise return this string. */
- (nonnull NSString *)stringByRemovingInvalidUTF8EncodedXMLCharacters;

/** Replace all solo ampersands (& characters) that aren't already part of either `&amp;`, `&quot;`, `&apos;`, `&lt;`, or `&gt;`, with `&amp;`.*/
- (nonnull NSString *)stringByEscapingUnescapedAmpersands;

/** Replace all HTML named entities (e.g. @c &nbsp;) with their numeric entity equivalents. */
- (nonnull NSString *)stringByReplacingHTMLNamedEntitiesWithNumericEntities;

/**
 
 Replace the characters &, ", ', < and > with their XML entity values:
 
 - &amp;
 - &quot;
 - &apos;
 - &lt;
 - &gt;
 
 */
- (nonnull NSString *)stringByEscapingAsXMLAttributeValue;

/**
 
 Replace the characters &, < and > with their XML entity values:
 
 - &amp;
 - &lt;
 - &gt;
 
 */
- (nonnull NSString *)stringByEscapingAsXMLTextContent;

/** When you have a string at hand that is assumed to contain XML text, but can be faster processed in case it is actually plain text, this method helps make that choice. */
- (BOOL)appearsToContainSerialisedXML;

@end


@interface NSXMLDocument (MPXMLExtensions)

/** Parse an XML string into an XML document. This implementation filters out invalid characters not allowed by the XML 1.0 specification, as well as sequences that aren't valid UTF-8, prior to parsing the input string. */
+ (nullable NSXMLDocument *)XMLDocumentFromString:(nonnull NSString *)XMLString
                                          options:(NSXMLNodeOptions)options
                                            error:(NSError *__nullable *__nullable)error;

/** Drops doctype and namespace definitions and returns the number of elements where a namespace was dropped. */
- (NSUInteger)exterminateDocTypeAndNamespaces;

@end
