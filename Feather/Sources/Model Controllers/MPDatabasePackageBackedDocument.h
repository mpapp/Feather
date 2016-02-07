//
//  MPDatabasePackageBackedDocument.h
//  Feather
//
//  Created by Matias Piipari on 10/07/2015.
//  Copyright (c) 2015 Matias Piipari. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <Feather/MPDatabasePackageController.h>

@class MPShoeboxPackageController;

extern NSString *const MPDatabasePackageBackedDocumentErrorDomain;

typedef NS_ENUM(NSUInteger, MPDatabasePackageBackedDocumentErrorCode) {
    MPDatabasePackageBackedDocumentErrorCodeUnknown = 0,
    MPDatabasePackageBackedDocumentErrorCodeWorkingPathMissing = 1,
    MPDatabasePackageBackedDocumentErrorCodePackageAccessFailed = 2
};

@interface MPDatabasePackageBackedDocument : NSDocument 

/** Initializes the internal state of the document, optionally creating the document's package directory in the process.
  * There are cases where yuo need to call this instead of relying on the document object initialization itself resulting to it getting called. */
- (BOOL)initializeStateCreatingDirectoryTree:(BOOL)create error:(NSError **)error;

/** Initializes a directory under the document bundle for storing document metadata.
  * The metadata written by a database backed document is eventually consistent with its current primary state and is intended for 
  * use by external apps and services to index, preview, summarise document contents in a way where consistency with primary state of the document is not essential. */
- (BOOL)initializeManuscriptMetadataDirectoryCreatingDirectory:(BOOL)create error:(NSError **)outError;

/** This message is sent to the document when it has created the database package. 
  * The base class implementation is empty so calling super is not necessary.
  * Use this callback to initialize and validate package controller's contents.
  * Return NO if the package controller is in an invalid state.
  * Return YES if the package controller is in a valid state. */
- (BOOL)initializePackageController:(MPDatabasePackageController *)packageController error:(NSError **)error;

/** YES if package access should not be permitted, NO if package access is permitted. */
@property (readwrite) BOOL packageAccessDenied;

/** Error occurred when attempting to access document's database package.
 * Set by accessing the lazily populated packageController property and never unset after that. */
@property (readonly, nonatomic) NSError *packageAccessError;

/** A path where a temporary copy of the document package bundle is created for runtime manipulation. */
@property (copy, readonly) NSString *temporaryManuscriptPath;

/** Directory containing the manuscript JSON used for indexing & recent manuscript metadata. */
@property (copy) NSString *temporaryManuscriptMetadataDirectoryPath;

/** Lazily initialized MPDatabasePackageController instance for the document of the class determined by -packageControllerClass.
  * NOTE! Initialized on accessing this property. */
@property (strong, readonly, nonatomic) id packageController;

/** Returns YES if packageController is initialized, NO otherwise. */
@property (readonly) BOOL packageControllerExists;

/** Abstract property that returns the MPDatabasePackageController subclass to use to initialize a package controller for the document. */
@property (readonly) Class packageControllerClass;

/** YES if bundle's directory structure has been initialized. 
  * Will only return YES once -initializeStateCreatingDirectoryTree:error: has been called without errors. */
@property (readonly) BOOL bundleInitialized;

/** Returns YES when the document's internal directory structure has been marked to require initialization.
  * Indicates that a state has been encountered after which state initialization (or potentially state re-initialization) is required, but can be YES also when bundleInitialized = YES.
  * Set this to YES in a subclass if you implement document reading lazily, where for instance -readFromURL: only marks the URL that needs to be read later. */
@property (readwrite, nonatomic) BOOL bundleRequiresInitialization;

/** YES if the specified type requires a copy of the original file read with -readFromURL:error: to be copied into a temporary working directory, 
  * NO if the type instead requires importing. */
+ (BOOL)requiresCopyingDocumentOfType:(NSString *)type atOriginalURL:(NSURL *)URL;

/** File URL given to the document when it was read originally from disk. */
@property (readwrite) NSURL *originalBundleFileURL;

/** The type of data that was read into the document. */
@property (readwrite) NSString *originalType;

/** Document state has been reverted */
@property (readonly) BOOL reverted;

/** A shorthand for getting the document's primary window controller. */
@property (readonly) id mainWindowController;

@end

#pragma mark -

/** A scripting oriented adapter that allows wrapping 1 shared package controller to n documents without having to introduce a top-level object. */
@interface MPSharedPackageControllerAdapter : NSObject
@property (readonly) MPShoeboxPackageController *sharedPackageController;
@property (readonly, weak) MPDatabasePackageBackedDocument *document;

- (instancetype)initWithContainer:(MPDatabasePackageBackedDocument *)document sharedPackageController:(MPShoeboxPackageController *)spkg;

@end


