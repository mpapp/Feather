//
//  MPManagedObject.h
//  Feather
//
//  Created by Matias Piipari on 16/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Cocoa;
@import Foundation;
@import CouchbaseLite;

#import "MPJSONRepresentable.h"

#import "MPCacheable.h"

#import "MPEmbeddedObject.h"
#import "MPEmbeddedPropertyContainingMixin.h"

extern NSString * _Nonnull const MPManagedObjectErrorDomain;

typedef NS_ENUM(NSInteger, MPManagedObjectErrorCode)
{
    MPManagedObjectErrorCodeUnknown = 0,
    MPManagedObjectErrorCodeTypeMissing = 1,
    MPManagedObjectErrorCodeUserNotCreator = 2,
    MPManagedObjectErrorCodeMissingBundledData = 3,
    MPManagedObjectErrorCodeMissingAttachment = 4,
    MPManagedObjectErrorCodeMissingController = 5,
    MPManagedObjectErrorCodeMissingDatabase = 6
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
extern NSString * _Nonnull const MPPasteboardTypeManagedObjectFull;

/** Pasteboard type for a minimal managed object representation with necessary identifiers to find the object by its ID and package controller ID. */
extern NSString * _Nonnull const MPPasteboardTypeManagedObjectID;

/** Pasteboard type for an array of object ID representations. */
extern NSString * _Nonnull const MPPasteboardTypeManagedObjectIDArray;

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
    <NSPasteboardWriting, NSPasteboardReading, MPCacheable, MPEmbeddingObject, MPJSONRepresentable>

/** The managed objects controller which manages (and caches) the object. */
@property (weak, readonly, nullable) __kindof MPManagedObjectsController *controller;

/** The _id of the document this model object represents. Non-nil always, even for deleted objects. */
@property (readonly, copy, nullable) NSString *documentID;

/** The document ID without the object type prefix. */
@property (readonly, copy, nullable) NSString *prefixlessDocumentID;

/** The creation date: the moment -save or -saveModels was issued the first time for the object. It is earlier than the exact moment at which the the object was created in the database. */
@property (readonly, assign, nullable) NSDate *createdAt;

/** The last update date: the moment -save or -saveModels was issued the last time. It is later than the last a property change was made, and earlier than the exact moment at which the update was registered in the database. */
@property (readonly, assign, nullable) NSDate *updatedAt;

/** Identifier automatically set by each save of this object to the value of the current session, but only if [self.class shouldTrackSessionID] returns YES. */
@property (readonly, nullable) NSString *sessionID;

/** The latest record change tag seen when pulling changes from CloudKit for this object. */
@property (readonly, nullable) NSString *cloudKitChangeTag;

/** The MPContributor who created the object. */
@property (readonly, strong, nullable) MPContributor *creator;

/** Array of MPContributor objects who have edited this document. Kept in the order of last editor: if you're A and the list of editors before your edit was [A,B,C], the array is reodered to [B,C,A]. */
@property (readonly, strong, nullable) NSArray *editors;

/** The complete set of scriptable properties for the scriptable object. */
@property (readwrite, copy, nonnull) NSDictionary *scriptingProperties;

/** Sets properties using a dictionary deriving from the scripting system, meaning that the dictionary can have object specifiers as values as well as other objects. */
- (void)setScriptingDerivedProperties:(nonnull NSDictionary *)scriptingDerivedProperties;

#pragma mark - Sharing & Moderation

/** The object has been marked shared by the user. Cannot guaranteed to be undone. */
@property (readonly, assign, getter=isShared) BOOL shared;

- (BOOL)shareWithError:(NSError *_Nullable *_Nullable)err;

/** The object's moderation state. By default has value MPManagedObjectModerationStateUnmoderated. Other values imply that the object is also marked shared. */
@property (readonly) MPManagedObjectModerationState moderationState;

/** The object has been moderated as either accepted or rejected by administrators of a shared managed object database. YES implies that the object is also marked shared.*/
@property (readonly) BOOL isModerated;

/** The object has been moderated as accepted by administrators of a shared managed object database. YES implies that the object is also marked shared. */
@property (readonly) BOOL isAccepted;
- (void)accept;

/** The object has been moderated as rejected by administrators of a shared managed object database. YES implies that the object is also marked shared. */
@property (readonly) BOOL isRejected;

/** Sets isRejected=YES if it weren't already. Intended to be called only if isRejected=NO. */
- (void)reject;

/** Returns a value transformed from the prototype object to the prototyped object. Can be for instance the original value, a placeholder value, a copy of the original value, or nil. For instance the property 'title' might be transformed to hide the user's set value for a title to just "Document title". */
- (nullable id)prototypeTransformedValueForPropertiesDictionaryKey:(nonnull NSString *)key
                                          forCopyOfPrototypeObject:(nonnull MPManagedObject *)mo;

/** A human readable name for a property key. Default implementation returns simply the key, capitalized. */
- (nonnull NSString *)humanReadableNameForPropertyKey:(nonnull NSString *)key;

/** The identifier of the object on which this object is based on. Implies that the object is a template. */
@property (readonly, copy, nullable) NSString *prototypeID;

/** The prototype object on which this object is based on. */
@property (readonly, strong, nullable) __kindof MPManagedObject *prototype;

/** The object is based on a prototype object. Implies prototype != nil. */
@property (readonly) BOOL hasPrototype;

/** The object can form a prototype. YES for MPManagedObject -- overload in subclasses with instances which should not be duplicated. */
@property (readonly) BOOL canFormPrototype;

/** The object can form a prototype when shared. NO for MPManagedObject -- overload in subclasses which should form prototypes when object is marked shared. */
@property (readonly) BOOL formsPrototypeWhenShared;

/** Indicates this object should currently not be allowed to be edited by the user. Useful, for example, for document-local copies of shared/bundled objects. */
@property (readonly, getter=isLocked) BOOL locked;

/** Mark objects which have been user contributed when there is also the possibility of the document instead having for instance been bundled with the app.
  * Note that to be userContributed / bundled (and e.g. therefore locked) are not mutually exclusive. */
@property (readwrite, getter=isUserContributed) BOOL userContributed;

/** KVC key corresponding to a property key stored in the object's backing dictionary. Base class implementation returns the argument value. */
- (nonnull NSString *)valueCodingKeyForPersistedPropertyKey:(nonnull NSString *)persistedPropertyKey;

/** Key used in object's persisted properties for a KVC key. Base class implementation returns the argument value. */
- (nonnull NSString *)persistedPropertyKeyForValueCodingKey:(nonnull NSString *)kvcKey;

- (void)lock;

- (void)unlock;

/** Saves and on failure posts an error notification on errors to the object's package controller's notification center. */
- (BOOL)save;

/** Synonymous to -save – done because -save and -saveWithError: end up being ambiguous in Swift (both map to save(), the error case mapping to a throwing method). */
- (BOOL)saveObject;

/** Saves the object, and all it’s embedded object typed properties, and managed object typed properties.
 * Also sends -deepSave: recursively to all managed and embedded objects referenced by the object. */
- (BOOL)deepSave:(NSError *_Nullable __autoreleasing * _Nullable)outError;

/** Deep saves and posts an error notification on errors to the object's package controller's notification center. */
- (BOOL)deepSave;

/** A shorthand for saving a number of model objects and on hitting an error posting an error notification to the package controller's notification center. */
+ (BOOL)saveModels:(nonnull NSArray<__kindof MPManagedObject *> *)models;

/** Whether this managed object has been deleted. */
@property (readonly) BOOL isDeleted;

/** A shorthand for deleting a model object and on hitting an error posting an error notification to the package controller's notification center. */
- (BOOL)deleteDocument;

/** Synonymous to -deleteDocument to make the Swift compiler (that does not like the ambiguous -deleteDocument and -deleteDocument:) happy. Hack hack! */
- (BOOL)deleteObject;

/** The full-text indexable properties for objects of this class. 
  * Default implementation includes none.
  * @return nil if object should not be included in the full-text index, and an array of property key strings. */
+ (nullable NSArray<NSString *> *)indexablePropertyKeys;

/** The full-text indexable string for a property key. 
  * Default implementation simply calls [self valueForKey:propertyKey] */
- (nullable NSString *)indexableStringForPropertyKey:(nonnull NSString *)propertyKey;

/** The tokenized full-text indexable string of the object contents. */
@property (readonly, copy, nonnull) NSString *tokenizedFullTextString;

/** Get a new document ID for this object type. Not to be called on MPManagedObject directly, but on its concrete subclasses. */
+ (nonnull NSString *)idForNewDocumentInDatabase:(nonnull CBLDatabase *)db;

/** Validation function for saves. All MPManagedObject revision saves (creation & update, NOT deletion) will be evaluated through this function. Default implementation returns YES. Note that there is no need to validate the presence of 'objectType' fields, required prefixing, or other universally required MPManagedObject properties here. Revisions for which this method is run are guaranteed to be non-deleted. */
+ (BOOL)validateRevision:(nonnull CBLRevision *)revision;

/** Return YES if a property with the given name is required _in the properties dictionary_. 
  * Default implementation returns NO to all properties, and at the time of writing is not used by MPManagedObject validateRevision: but is used by some subclasses. */
+ (BOOL)requiresProperty:(nonnull NSString *)property;

/** Return YES if instances of this class should track a session ID, NO otherwise. Default implementation returns NO.
  * Session ID tracking can be helpful when you want to make behaviour conditional on whether your client on the present session made a change, or 
  * whether it was another client or the same app on a previous time it was run. */
+ (BOOL)shouldTrackSessionID;

+ (nonnull Class)managedObjectClassFromDocumentID:(nonnull NSString *)documentID;

/** Canonicalization removes a http://, https:// scheme, 
  * as well as replacing  ':', '/' and '.' characters with a '-'. */
+ (nonnull NSString *)canonicalizedIdentifierStringForString:(nonnull NSString *)string;

/** Human readable name for the type */
+ (nonnull NSString *)humanReadableName;

/** Like propertiesToSave, but drops "_id", "_rev", "attachments" and other CouchDB specifics + "objectType". */
@property (readonly, copy, nonnull) NSDictionary *nonIdentifiableProperties;

/** A representation of the object with identifier, object type and database package ID keys included. 
 * The dictionary can be resolved to an existing object with +objectWithReferableDictionaryRepresentation. */
@property (readonly, nullable) NSDictionary *referableDictionaryRepresentation;

/** Constructs a MPManagedObject instance of the type specified in the given referable dictionary representation.
  * Intended for creating managed objects from their pasteboard property list representations. */
+ (nonnull instancetype)objectWithReferableDictionaryRepresentation:(nonnull NSDictionary *)referableDictionaryRep;



/**
 *  Returns an object ID array pasteboard representation for a collection of managed objects.
 */
+ (nonnull NSData *)pasteboardObjectIDPropertyListForObjects:(nonnull NSArray *)objectIDDictionaries error:(NSError *_Nullable *_Nullable)err;

/** These pasteboard types should be returned as promises. */
+ (nonnull NSSet<NSString *> *)promisedPasteboardTypes;

/** String representation of a JSON encodable dictionary representation of the object. By default the representation does not contain referenced objects, but subclasses can override to embed ("denormalise") referenced objects. */
- (nonnull NSString *)JSONStringRepresentation:(NSError *_Nullable *_Nullable)err;

/** A JSON encodable dictionary representation of the object. By default the representation does not contain referenced objects, but subclasses can override to embed ("denormalise") referenced objects. */
@property (readonly, copy, nonnull) NSDictionary *JSONEncodableDictionaryRepresentation;

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
- (nonnull instancetype)initWithNewDocumentForController:(nonnull MPManagedObjectsController *)controller;

/** Initialise a managed object with a specified controller, properties and identifier and a document ID. */
- (nonnull instancetype)initWithNewDocumentForController:(nonnull MPManagedObjectsController *)controller
                                              properties:(nullable NSDictionary<NSString *, id> *)properties
                                              documentID:(nullable NSString *)identifier;

/** Initializer used to when creating a new object with a given prototype.
  * Override in subclass if initialising when copying with a prototype should go a different route. */
- (nonnull instancetype)initWithNewDocumentForController:(nonnull MPManagedObjectsController *)controller
                                               prototype:(nullable __kindof MPManagedObject *)prototype;

/** Initialise a managed object with a new document managed by the specified controller.
  * @param managedObject a non-nil managed object of the same class as the object being returned.
  * @param controller The managed object controller for this object. Must not be nil, but may be different to the controller of managedObject.
  * */
- (nonnull instancetype)initCopyOfManagedObject:(nonnull MPManagedObject *)managedObject
                                     controller:(nonnull MPManagedObjectsController *)controller;

/** A utility method which helps implementing setters for properties which have a managed object subclass as their type (e.g. 'section' as property key is internally stored as 'sectionIDs', setter stores document IDs).  */
- (void)setObjectIdentifierArrayValueForManagedObjectArray:(nullable NSArray<__kindof MPManagedObject *> *)objectArray
                                                  property:(nonnull NSString *)propertyKey;

/** A utility method which helps implementing getters for properties which have a managed object subclass as their intended type (e.g. 'section' as property key is internally stored as 'sectionIDs', getter retrieves objects by document ID).  */
- (nonnull NSArray<__kindof MPManagedObject *> *)getValueOfObjectIdentifierArrayProperty:(nonnull NSString *)propertyKey;

- (void)setObjectIdentifierSetValueForManagedObjectArray:(nullable NSArray<__kindof MPManagedObject *> *)objectSet
                                                property:(nonnull NSString *)propertyKey;

- (nonnull NSSet<__kindof MPManagedObject *> *)getValueOfObjectIdentifierSetProperty:(nullable NSString *)propertyKey;

/** Set values to an object embedded in a dictionary typed property (e.g. key "R" embedded in dictionary under key "scimago". */
- (void)setDictionaryEmbeddedValue:(nonnull id)value
                            forKey:(nonnull NSString *)embeddedKey
                        ofProperty:(nonnull NSString *)dictPropertyKey;

/** Get value of an objec*/
- (nullable id)getValueForDictionaryEmbeddedKey:(nonnull NSString *)embeddedKey
                                     ofProperty:(nonnull NSString *)dictPropertyKey;

#pragma mark - Attachments

/** Replaces the current citation style with the same name if one was there already. */
- (BOOL)attachContentsOfURL:(nonnull NSURL *)newAttachmentURL
         withAttachmentName:(nonnull NSString *)name
                contentType:(nonnull NSString *)contentType
                      error:(NSError *_Nullable *_Nullable)err;

/** Create an attachment with string.
 * @param name The name of the attachment. Must be unique per managed object (there can be multiple attachments in the database with the same name, but not multiple for the same managed object).
 * @param string String which will be stored as the attachment data.
 * @param type The content type of the attachment (MIME type).
 * @param err An optional error pointer.
 */
- (BOOL)createAttachmentWithName:(nonnull NSString *)name
                      withString:(nonnull NSString *)string
                            type:(nonnull NSString *)type
                           error:(NSError *_Nullable *_Nullable)err;

/** Create an attachment with string.
 * @param name The name of the attachment. Must be unique per managed object (there can be multiple attachments in the database with the same name, but not multiple for the same managed object).
 * @param url The URL from which the attachment data is read.
 * @param type Optional content type of the attachment (MIME type). If nil is given, an attempt is made to determine the file type from the file contents.
 * @param err An optional error pointer.
 */
- (BOOL)createAttachmentWithName:(nonnull NSString *)name
               withContentsOfURL:(nonnull NSURL *)url
                            type:(nonnull NSString *)type
                           error:(NSError *_Nullable *_Nullable)err;


/** A method which is called after successful initialisation steps but before the object is returned. Can be overloaded by subclasses (oveloaded methods should call the superclass -didInitialize). This method should not be called directly. */
- (void)didInitialize; // overload but don't call manually

#pragma mark - Scripting

/** Object specifier key for scripting support (the property key in the container) for the *class*. Default implementation: MPManagedObject -> 'allManagedObjects'. Need not be, but can be, overloaded. The container for objects of this type must implement a property with the corresponding name (for instance allManagedObjects).  */
+ (nonnull NSString *)objectSpecifierKey;

/** Object specifier key for scripting support for the *instance*. Default implementation calls +objectSpecifierKey. Need not be, but can be, overloaded. */
@property (readonly, copy, nonnull) NSString *objectSpecifierKey;

// FIXME: This does not really belong in MPManagedObject.
/** String representing the camel cased singular form of instances of this class, useful for property naming. */
+ (nonnull NSString *)singular;

// FIXME: This does not really belong in MPManagedObject.
/** String representing the camel cased plural form of instances of this class, useful for property naming. */
+ (nonnull NSString *)plural;

#pragma mark - 

#if MP_DEBUG_ZOMBIE_MODELS
+ (void)clearModelObjectMap;
#endif

@end


#pragma mark -

/** A proxy object which calls -save every time setValue:forKey: is called. */
@interface MPAutosavingManagedObjectProxy : NSProxy
@property (readonly, nonnull) MPManagedObject *managedObject;
- (nonnull instancetype)initWithObject:(nonnull MPManagedObject *)o;
@end
