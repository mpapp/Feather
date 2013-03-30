//
//  NSDictionary+MPManagedObject.h
//  Manuscripts
//
//  Created by Matias Piipari on 12/10/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const MPManagedObjectDictionaryErrorDomain;

typedef enum MPManagedObjectDictionaryValidationErrorCode
{
    MPManagedObjectDictionaryValidationErrorCodeUnknown = 0,
    MPManagedObjectDictionaryValidationErrorCodeObjectTypeMissing = 1,
    MPManagedObjectDictionaryValidationErrorCodeObjectTypeInvalid = 2,
    MPManagedObjectDictionaryValidationErrorCodeDocumentIDMissing = 3,
    MPManagedObjectDictionaryValidationErrorCodeUnexpectedDocumentID = 4
} MPManagedObjectDictionaryValidationErrorCode;

/** A MPManagedObject utility category for NSDictionary: includes a method to validate that a NSDictionary contains a representation of a MPManagedObject, and shorthand properties for managed object related properties. */
@interface NSDictionary (MPManagedObject)

@property (readonly, copy) NSString *managedObjectType;
@property (readonly, copy) NSString *managedObjectDocumentID;
@property (readonly, copy) NSString *managedObjectRevisionID;

- (BOOL)isManagedObjectDictionary:(NSError **)error;

@end
