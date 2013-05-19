//
//  MPManagedObject.h
//  Feather
//
//  Created by Matias Piipari on 16/09/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CouchCocoa/CouchCocoa.h>

#import "MPCacheable.h"

#import "MPEmbeddedObject.h"
#import "MPEmbeddedPropertyContainingMixin.h"

extern NSString * const MPManagedObjectErrorDomain;

typedef NS_ENUM(NSInteger, MPManagedObjectErrorCode)
{
    MPManagedObjectErrorCodeUnknown = 0,
    MPManagedObjectErrorCodeTypeMissing = 1,
    MPManagedObjectErrorCodeUserNotCreator = 2
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


/** An empty tag protocol used to signify objects which can be referenced across database boundaries.
  * This information is used to determine the correct controller for an object. */
@protocol MPReferencableObject <NSObject>
@end

@interface MPReferencableObjectMixin : NSObject
@end

@class MPManagedObjectsController, CouchModel;
@class MPContributor;

/**
 * An abstract base class for all objects contained in a MPDatabase (n per MPDatabase), except for MPMetadata (1 per MPDatabase).
 */
@interface MPManagedObject : CouchModel
    <NSPasteboardWriting, NSPasteboardReading, MPCacheable, MPEmbeddingObject>

/** The managed objects controller which manages (and caches) the object. */
@property (weak, readonly) MPManagedObjectsController *controller;

/** The _id of the document this model object represents. Non-nil always, even for deleted objects. */
@property (readonly, copy) NSString *documentID;

/** The creation date: the moment -save or -saveModels was issued the first time for the object. It is earlier than the exact moment at which the the object was created in the database. */
@property (readonly, assign) NSDate *createdAt;

/** The last update date: the moment -save or -saveModels was issued the last time. It is later than the last a property change was made, and earlier than the exact moment at which the update was registered in the database. */
@property (readonly, assign) NSDate *updatedAt;

/** The _id of the MPContributor who created the object. */
@property (readonly, strong) NSString *creatorID;

/** The MPContributor who created the object. */
@property (readonly, strong) MPContributor *creator;

/** Array of _id's to the MPContributor objects who have edited this document. Kept in the order of last editor. Kept in the order of last editor: if you're A and the list of editors before your edit was [A,B,C], the array is reodered to [B,C,A]. */
@property (readonly, strong) NSArray *editorIDs;

/** Array of MPContributor objects who have edited this document. Kept in the order of last editor: if you're A and the list of editors before your edit was [A,B,C], the array is reodered to [B,C,A]. */
@property (readonly, strong) NSArray *editors;

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

/** The identifier of the object on which this object is based on. Implies that the object is a template. */
@property (readonly, copy) NSString *prototypeID;

/** Returns a value transformed from the prototype object to the prototyped object. Can be for instance the original value, a placeholder value, a copy of the original value, or nil. For instance the property 'title' might be transformed to hide the user's set value for a title to just "Document title". */
- (id)prototypeTransformedValueForPropertiesDictionaryKey:(NSString *)key forCopyManagedByController:(MPManagedObjectsController *)cc;

/** A human readable name for a property key. Default implementation returns simply the key, capitalized. */
- (NSString *)humanReadableNameForPropertyKey:(NSString *)key;

/** The prototype object on which this object is based on. */
@property (readonly, strong) id prototype;

/** The object is based on a prototype object. Implies prototype != nil. */
@property (readonly) BOOL hasPrototype;

/** The object can form a prototype. YES for MPManagedObject -- overload in subclasses with instances which should not be duplicated. */
@property (readonly) BOOL canFormPrototype;

/** The object can form a prototype when shared. NO for MPManagedObject -- overload in subclasses which should form prototypes when object is marked shared. */
@property (readonly) BOOL formsPrototypeWhenShared;

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
+ (NSString *)idForNewDocumentInDatabase:(CouchDatabase *)db;

/** Validation function for saves. All MPManagedObject revision saves (creation & update, NOT deletion) will be evaluated through this function. Default implementation returns YES. Note that there is no need to validate the presence of 'objectType' fields, required prefixing, or other universally required MPManagedObject properties here. Revisions for which this method is run are guaranteed to be non-deleted. */
+ (BOOL)validateRevision:(TD_Revision *)revision;

+ (Class)managedObjectClassFromDocumentID:(NSString *)documentID;

/** Human readable name for the type */
+ (NSString *)humanReadableName;

/** The pasteboard representation type name for the object. Can be overloaded by subclasses which wish to use a different representation type than what MPManagedObject provides. */
+ (NSString *)pasteboardTypeName;

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
- (CouchAttachment *)createAttachmentWithName:(NSString *)name
                                   withString:(NSString *)string
                                         type:(NSString *)type
                                        error:(NSError **)err;

/** Create an attachment with string.
 * @param name The name of the attachment. Must be unique per managed object (there can be multiple attachments in the database with the same name, but not multiple for the same managed object).
 * @param url The URL from which the attachment data is read.
 * @param type Optional content type of the attachment (MIME type). If nil is given, an attempt is made to determine the file type from the file contents.
 * @param err An optional error pointer.
 */
- (CouchAttachment *)createAttachmentWithName:(NSString*)name
                            withContentsOfURL:(NSURL *)url
                                         type:(NSString *)type
                                        error:(NSError **)err;


/** A method which is called after successful initialisation steps but before the object is returned. Can be overloaded by subclasses (oveloaded methods should call the superclass -didInitialize). This method should not be called directly. */
- (void)didInitialize; // overload but don't call manually

#pragma mark - 

#if MP_DEBUG_ZOMBIE_MODELS
+ (void)clearModelObjectMap;
#endif

@end