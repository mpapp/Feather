//
//  MPManagedObject.h
//  Feather
//
//  Created by Matias Piipari on 16/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CouchbaseLite/CouchbaseLite.h>

#import "MPCacheable.h"

#import "MPEmbeddedObject.h"
#import "MPEmbeddedPropertyContainingMixin.h"

extern NSString * const MPManagedObjectErrorDomain;

typedef NS_ENUM(NSInteger, MPManagedObjectErrorCode)
{
    MPManagedObjectErrorCodeUnknown = 0,
    MPManagedObjectErrorCodeTypeMissing = 1,
    MPManagedObjectErrorCodeUserNotCreator = 2,
    MPManagedObjectErrorCodeMissingBundledData = 3,
    MPManagedObjectErrorCodeMissingAttachment = 4
};

typedef NS_ENUM(NSInteger, MPManagedObjectModerationState)
{
    MPManagedObjectModerationStateUnmoderated = 0,
    MPManagedObjectModerationStateAccepted = 1,
    MPManagedObjectModerationStateRejected = 2
};

typedef NS_ENUM(NSInteger, MPManagedObjectChangeSource)
{
    MPManagedObjectChangeSourceInternal = 0,    // internal change (change assumed internal if no source given)
    MPManagedObjectChangeSourceAPI = 1,         // change made in in-process via the RESTful web service API ( touchdb:// or http(s):// )
    MPManagedObjectChangeSourceExternal = 2     // changes coming in from external source ( e.g. replication )
};

/** Pasteboard type for a full managed object. */
extern NSString *const MPPasteboardTypeManagedObjectFull;

/** Pasteboard type for a minimal managed object representation with necessary identifiers to find the object by its ID and package controller ID. */
extern NSString *const MPPasteboardTypeManagedObjectID;

/** Pasteboard type for an array of object ID representations. */
extern NSString *const MPPasteboardTypeManagedObjectIDArray;

/** An empty tag protocol used to signify objects which can be referenced across database boundaries.
  * This information is used to determine the correct controller for an object. */
@protocol MPReferencableObject <NSObject>
@end

@interface MPReferencableObjectMixin : NSObject
@end

@class MPManagedObjectsController;
@class MPContributor;

/**
 * An abstract base class for all objects contained in a MPDatabase (n per MPDatabase), except for MPMetadata (1 per MPDatabase).
 * 
 * An MPManagedObject has a JSON serialisation format, and as such it can contain persistent properties of basic types,
 * as well as NSString, NSDate, NSNumber objects, MPManagedObject (encoded as a document ID) as well as NSArray and NSDictionary collections.
 *
 * An NSArray or NSDictionary typed property of a MPManagedObject
 * can contain any of the types that can be contained directly as properties of MPManagedObject,
 * including MPEmbeddedObject, in the special case where the property name is prefixed with 'embedded' 
 * (the prefix is there to act as an annotation to denote the type of the contents in the collection).
 */
@interface MPManagedObject : CBLModel
    <NSPasteboardWriting, NSPasteboardReading, MPCacheable, MPEmbeddingObject>

/** The managed objects controller which manages (and caches) the object. */
@property (weak, readonly) MPManagedObjectsController *controller;

/** The _id of the document this model object represents. Non-nil always, even for deleted objects. */
@property (readonly, copy) NSString *documentID;

/** The creation date: the moment -save or -saveModels was issued the first time for the object. It is earlier than the exact moment at which the the object was created in the database. */
@property (readonly, assign) NSDate *createdAt;

/** The last update date: the moment -save or -saveModels was issued the last time. It is later than the last a property change was made, and earlier than the exact moment at which the update was registered in the database. */
@property (readonly, assign) NSDate *updatedAt;

/** The MPContributor who created the object. */
@property (readonly, strong) MPContributor *creator;

/** Array of MPContributor objects who have edited this document. Kept in the order of last editor: if you're A and the list of editors before your edit was [A,B,C], the array is reodered to [B,C,A]. */
@property (readonly, strong) NSArray *editors;

/** The complete set of scriptable properties for the scriptable object. */
@property (readwrite, copy) NSDictionary *scriptingProperties;

/** Sets properties using a dictionary deriving from the scripting system, meaning that the dictionary can have object specifiers as values as well as other objects. */
- (void)setScriptingDerivedProperties:(NSDictionary *)scriptingDerivedProperties;

#pragma mark - Sharing & Moderation

/** The object has been marked shared by the user. Cannot guaranteed to be undone. */
@property (readonly, assign, getter=isShared) BOOL shared;

- (void)shareWithError:(NSError **)err;

/** The object's moderation state. By default has value MPManagedObjectModerationStateUnmoderated. Other values imply that the object is also marked shared. */
@property (readonly, assign) MPManagedObjectModerationState moderationState;

/** The object has been moderated as either accepted or rejected by administrators of a shared managed object database. YES implies that the object is also marked shared.*/
@property (readonly, assign) BOOL isModerated;

/** The object has been moderated as accepted by administrators of a shared managed object database. YES implies that the object is also marked shared. */
@property (readonly, assign) BOOL isAccepted;
- (void)accept;

/** The object has been moderated as rejected by administrators of a shared managed object database. YES implies that the object is also marked shared. */
@property (readonly, assign) BOOL isRejected;
- (void)reject;

/** Returns a value transformed from the prototype object to the prototyped object. Can be for instance the original value, a placeholder value, a copy of the original value, or nil. For instance the property 'title' might be transformed to hide the user's set value for a title to just "Document title". */
- (id)prototypeTransformedValueForPropertiesDictionaryKey:(NSString *)key forCopyManagedByController:(MPManagedObjectsController *)cc;

/** A human readable name for a property key. Default implementation returns simply the key, capitalized. */
- (NSString *)humanReadableNameForPropertyKey:(NSString *)key;

/** The identifier of the object on which this object is based on. Implies that the object is a template. */
@property (readonly, copy) NSString *prototypeID;

/** The prototype object on which this object is based on. */
@property (readonly, strong) id prototype;

/** The object is based on a prototype object. Implies prototype != nil. */
@property (readonly) BOOL hasPrototype;

/** The object can form a prototype. YES for MPManagedObject -- overload in subclasses with instances which should not be duplicated. */
@property (readonly) BOOL canFormPrototype;

/** The object can form a prototype when shared. NO for MPManagedObject -- overload in subclasses which should form prototypes when object is marked shared. */
@property (readonly) BOOL formsPrototypeWhenShared;

/** Saves and posts an error notification on errors to the object's package controller's notification center. */
- (BOOL)save;

/** A shorthand for saving a number of model objects and on hitting an error posting an error notification to the package controller's notification center. */
+ (BOOL)saveModels:(NSArray *)models;

/** A shorthand for deleting a model object and on hitting an error posting an error notification to the package controller's notification center. */
- (BOOL)deleteDocument;

/** The full-text indexable properties for objects of this class. 
  * Default implementation includes none.
  * @return nil if object should not be included in the full-text index, and an array of property key strings. */
+ (NSArray *)indexablePropertyKeys;

/** The full-text indexable string for a property key. 
  * Default implementation simply calls [self valueForKey:propertyKey] */
- (NSString *)indexableStringForPropertyKey:(NSString *)propertyKey;

/** The tokenized full-text indexable string of the object contents. */
@property (readonly, copy) NSString *tokenizedFullTextString;

/** Get a new document ID for this object type. Not to be called on MPManagedObject directly, but on its concrete subclasses. */
+ (NSString *)idForNewDocumentInDatabase:(CBLDatabase *)db;

/** Validation function for saves. All MPManagedObject revision saves (creation & update, NOT deletion) will be evaluated through this function. Default implementation returns YES. Note that there is no need to validate the presence of 'objectType' fields, required prefixing, or other universally required MPManagedObject properties here. Revisions for which this method is run are guaranteed to be non-deleted. */
+ (BOOL)validateRevision:(CBLRevision *)revision;

+ (Class)managedObjectClassFromDocumentID:(NSString *)documentID;

/** Human readable name for the type */
+ (NSString *)humanReadableName;

/** A representation of the object with identifier, object type and database package ID keys included. 
 * The dictionary can be resolved to an existing object with +objectWithReferableDictionaryRepresentation. */
@property (readonly) NSDictionary *referableDictionaryRepresentation;

+ (id)objectWithReferableDictionaryRepresentation:(NSDictionary *)referableDictionaryRep;

/**
 *  Returns an object ID array pasteboard representation for a collection of managed objects.
 */
+ (NSData *)pasteboardObjectIDPropertyListForObjects:(NSArray *)objectIDDictionaries error:(NSError **)err;

/** String representation of a JSON encodable dictionary representation of the object. By default the representation does not contain referenced objects, but subclasses can override to embed ("denormalise") referenced objects. */
- (NSString *)JSONStringRepresentation:(NSError **)err;

/** A JSON encodable dictionary representation of the object. By default the representation does not contain referenced objects, but subclasses can override to embed ("denormalise") referenced objects. */
@property (readonly, copy) NSDictionary *JSONEncodableDictionaryRepresentation;

/** 
 * The class is intended to be made concrete instances of. 
 * Default implementation checks if the class has subclasses, and is considered concrete if it has none. 
 * This behaviour is something you might want to override in subclasses and is added to guard from accidentally creating instances of objects intended to be abstract (thanks to ObjC / Swift not including an abstract keyword).
 */
+ (BOOL)isConcrete;

/**
* Initialise a managed object with a new document managed by the specified controller.
 * @param controller The managed object controller for this object. Must not be nil.
 */
- (instancetype)initWithNewDocumentForController:(MPManagedObjectsController *)controller;

/** A utility method which helps implementing setters for properties which have a managed object subclass as their type (e.g. 'section' as property key is internally stored as 'sectionIDs', setter stores document IDs).  */
- (void)setObjectIdentifierArrayValueForManagedObjectArray:(NSArray *)objectArray property:(NSString *)propertyKey;

/** A utility method which helps implementing getters for properties which have a managed object subclass as their intended type (e.g. 'section' as property key is internally stored as 'sectionIDs', getter retrieves objects by document ID).  */
- (NSArray *)getValueOfObjectIdentifierArrayProperty:(NSString *)propertyKey;

- (void)setObjectIdentifierSetValueForManagedObjectArray:(NSSet *)objectSet property:(NSString *)propertyKey;

- (NSSet *)getValueOfObjectIdentifierSetProperty:(NSString *)propertyKey;

/** Set values to an object embedded in a dictionary typed property (e.g. key "R" embedded in dictionary under key "scimago". */
- (void)setDictionaryEmbeddedValue:(id)value forKey:(NSString *)embeddedKey ofProperty:(NSString *)dictPropertyKey;
/** Get value of an objec*/
- (id)getValueForDictionaryEmbeddedKey:(NSString *)embeddedKey ofProperty:(NSString *)dictPropertyKey;

#pragma mark - Attachments

/** Create an attachment with string.
 * @param name The name of the attachment. Must be unique per managed object (there can be multiple attachments in the database with the same name, but not multiple for the same managed object).
 * @param string String which will be stored as the attachment data.
 * @param type The content type of the attachment (MIME type).
 * @param err An optional error pointer.
 */
- (void)createAttachmentWithName:(NSString *)name
                      withString:(NSString *)string
                            type:(NSString *)type
                           error:(NSError **)err;

/** Create an attachment with string.
 * @param name The name of the attachment. Must be unique per managed object (there can be multiple attachments in the database with the same name, but not multiple for the same managed object).
 * @param url The URL from which the attachment data is read.
 * @param type Optional content type of the attachment (MIME type). If nil is given, an attempt is made to determine the file type from the file contents.
 * @param err An optional error pointer.
 */
- (void)createAttachmentWithName:(NSString*)name
               withContentsOfURL:(NSURL *)url
                            type:(NSString *)type
                           error:(NSError **)err;


/** A method which is called after successful initialisation steps but before the object is returned. Can be overloaded by subclasses (oveloaded methods should call the superclass -didInitialize). This method should not be called directly. */
- (void)didInitialize; // overload but don't call manually

#pragma mark - Scripting

/** Object specifier key for scripting support (the property key in the container) for the *class*. Default implementation: MPManagedObject -> 'allManagedObjects'. Need not be, but can be, overloaded. The container for objects of this type must implement a property with the corresponding name (for instance allManagedObjects).  */
+ (NSString *)objectSpecifierKey;

/** Object specifier key for scripting support for the *instance*. Default implementation calls +objectSpecifierKey. Need not be, but can be, overloaded. */
@property (readonly, copy) NSString *objectSpecifierKey;

/** String representing the camel cased singular form of instances of this class, useful for property naming. */
+ (NSString *)singular;

/** String representing the camel cased plural form of instances of this class, useful for property naming. */
+ (NSString *)plural;

#pragma mark - 

#if MP_DEBUG_ZOMBIE_MODELS
+ (void)clearModelObjectMap;
#endif

@end