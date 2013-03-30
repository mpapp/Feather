//
//  NSDictionary+MPManagedObject.m
//  Manuscripts
//
//  Created by Matias Piipari on 12/10/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
//

NSString * const MPManagedObjectDictionaryErrorDomain = @"MPManagedObjectDictionaryErrorDomain";

#import "NSDictionary+MPManagedObjectExtensions.h"
#import "MPManagedObject.h"
#import "NSError+Manuscripts.h"

@implementation NSDictionary (MPManagedObject)

- (NSString *)managedObjectType { return self[@"objectType"]; }
- (NSString *)managedObjectDocumentID { return self[@"_id"]; }
- (NSString *)managedObjectRevisionID { return self[@"_rev"]; }

- (BOOL)isManagedObjectDictionary:(NSError **)error
{
    NSString *objectTypeStr = [self managedObjectType];
    if (!objectTypeStr)
    {
        if (error)
            *error = [NSError errorWithDomain:MPManagedObjectDictionaryErrorDomain
                                         code:MPManagedObjectDictionaryValidationErrorCodeDocumentIDMissing
                                  description:[NSString stringWithFormat:@"objectType is missing: %@", self]];
        return NO;
    }
    if (![NSClassFromString(objectTypeStr) isSubclassOfClass:[MPManagedObject class]])
    {
        if (error)
            *error = [NSError errorWithDomain:MPManagedObjectDictionaryErrorDomain
                                         code:MPManagedObjectDictionaryValidationErrorCodeObjectTypeInvalid
                                  description:[NSString stringWithFormat:@"%@ is not a MPManagedObject subclass: %@", objectTypeStr, self]];
        return NO;
    }
    
    NSString *docID = [self managedObjectDocumentID];
    if (!docID)
    {
        if (error)
            *error = [NSError errorWithDomain:MPManagedObjectDictionaryErrorDomain
                                         code:MPManagedObjectDictionaryValidationErrorCodeDocumentIDMissing
                                  description:[NSString stringWithFormat:@"Document ID is missing: %@", self]];
        return NO;
    }
    
    NSArray *docIDComponents = [docID componentsSeparatedByString:@":"];
    if ([docIDComponents count] != 2)
    {
        if (error)
            *error = [NSError errorWithDomain:MPManagedObjectDictionaryErrorDomain
                                         code:MPManagedObjectDictionaryValidationErrorCodeUnexpectedDocumentID
                                  description:[NSString stringWithFormat:@"Unexpected document ID: %@", self]];
        return NO;
    }
    
    if (![docIDComponents[0] isEqualToString:objectTypeStr])
    {
        if (error)
            *error = [NSError errorWithDomain:MPManagedObjectDictionaryErrorDomain
                                         code:MPManagedObjectDictionaryValidationErrorCodeUnexpectedDocumentID
                                  description:[NSString stringWithFormat:@"Unexpected document ID: %@", self]];
        return NO;
    }
    
    return YES;
}

@end