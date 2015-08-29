//
//  MPDatabasePackageBackedDocument.m
//  Feather
//
//  Created by Matias Piipari on 10/07/2015.
//  Copyright (c) 2015 Matias Piipari. All rights reserved.
//

#import "MPDatabasePackageBackedDocument.h"

#import <Feather/Feather.h>
#import <FeatherExtensions/FeatherExtensions.h>

NSString *const MPDatabasePackageBackedDocumentErrorDomain = @"MPDatabasePackageBackedDocumentErrorDomain";

@interface MPDatabasePackageBackedDocument () {
    id _packageController;
}
@property (readwrite, nonatomic) NSError *packageAccessError;
@end

@implementation MPDatabasePackageBackedDocument

// called when reading a document.
- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        NSError *err = nil;
        if (!self.packageAccessDenied && ![self initializeStateCreatingDirectoryTree:NO error:&err]) {
            NSAssert(err, @"ERROR: %@", err);
            self = nil;
            return self;
        }
    }
    return self;
}

- (instancetype)initWithType:(NSString *)typeName error:(NSError **)outError
{
    [MPShoeboxPackageController sharedShoeboxController];
    
    if (self = [super init])
    {
        _bundleRequiresInitialization = YES;
    }
    
    return self;
}

- (BOOL)initializeStateCreatingDirectoryTree:(BOOL)create error:(NSError **)error {
    NSParameterAssert(!self.packageAccessDenied);
    //NSParameterAssert([NSThread isMainThread]);
    
    if (_bundleInitialized) {
        return YES;
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (!_temporaryManuscriptPath) {
        _temporaryManuscriptPath = [[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]
                                    stringByAppendingPathComponent:@"untitled.manuscript"];
    }
    
    if (create && ![fm createDirectoryAtPath:_temporaryManuscriptPath withIntermediateDirectories:YES attributes:nil error:error]) {
        return NO;
    }
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
    
    _bundleRequiresInitialization = NO;
    _bundleInitialized = YES;
    
    return YES;
}

- (void)setBundleRequiresInitialization:(BOOL)bundleRequiresInitialization {
    if (_bundleRequiresInitialization == bundleRequiresInitialization) {
        return;
    }
    
    _bundleRequiresInitialization = bundleRequiresInitialization;
    
    if (_bundleRequiresInitialization) {
        //_bundleInitialized = NO;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[_packageController notificationCenter] removeObserver:self];
    
    [self cleanUpTemporaryFiles];
}

- (void)close {
    [super close];
    
    [_packageController close];
    _packageController = nil;
    
    [self cleanUpTemporaryFiles];
}

- (void)cleanUpTemporaryFiles
{
    if (!_temporaryManuscriptPath)
        return;
    
    // if _temporaryManuscriptPath exists,
    // document was saved the first time => need to remove the original temporary file ourselves.
    
    NSError *err = nil;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:_temporaryManuscriptPath])
        [fm removeItemAtPath:_temporaryManuscriptPath error:&err];
    
    if (err) {
        NSLog(@"Could not clean up temporary manuscript file: %@", err);
    }
    
    _temporaryManuscriptPath = nil;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    if (_packageController) {
        [(MPDatabasePackageController *)_packageController close];
        _packageController = nil;
    }
    [self cleanUpTemporaryFiles];
}


- (BOOL)packageControllerExists {
    return _packageController != nil;
}

- (Class)packageControllerClass {
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

- (BOOL)initializeManuscriptMetadataDirectoryCreatingDirectory:(BOOL)create error:(NSError **)outError {
    NSFileManager *fm = NSFileManager.defaultManager;
    
    // can be safely called multiple times - ivar initialization only done on first.
    if (!_temporaryManuscriptMetadataDirectoryPath) {
        NSAssert(_temporaryManuscriptPath,
                 @"temporaryManuscriptPath should be initialized before -initializeManuscriptMetadataDirectory: is called.");
        
        _temporaryManuscriptMetadataDirectoryPath = [_temporaryManuscriptPath stringByAppendingPathComponent:@"metadata"];
    }
    
    // metadata directory is not created in case the temporary manuscript path doesn't yet exist.
    // this can be the case for instance for a document whose temporary working path is to be created with the contents of self.fileURL
    // (i.e. an existing document whose contents are copied into the working directory).
    if (create && [fm fileExistsAtPath:_temporaryManuscriptPath]) {
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:_temporaryManuscriptMetadataDirectoryPath isDirectory:&isDir]) {
            if (![fm createDirectoryAtPath:_temporaryManuscriptMetadataDirectoryPath
               withIntermediateDirectories:NO
                                attributes:nil
                                     error:outError])
                return NO;
        }
    }
    
    return YES;
}

- (MPDatabasePackageController *)packageController {
    if (_packageController) {
        return _packageController;
    }
    
    NSError *error = nil;
    
    // if no _temporaryManuscriptPath
    if (_bundleRequiresInitialization && !_temporaryManuscriptPath) {
        if (![self initializeStateCreatingDirectoryTree:YES error:&error]) {
            NSLog(@"Failed initializing document: %@", error);
            self.packageAccessError = error;
            return nil;
        }
    }
    else  {
        NSAssert(_temporaryManuscriptPath,
                 @"Unexpected state: !temporaryManuscriptPath && !bundleRequiresInitialization");
    }
    
    NSAssert(_temporaryManuscriptPath, @"temporaryManuscriptPath should be set (%@)", self.fileURL);
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // Create temporary working copy of the project that is outside of the NSDocument system's remit.
    // ... if it wasn't already created above by _initCreatingDirectoryTree: (brr).
    NSString *tempManuscriptContainingDirPath = [_temporaryManuscriptPath stringByDeletingLastPathComponent];
    BOOL tempManuscriptContainingDirExists = NO;
    if (![fm fileExistsAtPath:_temporaryManuscriptPath isDirectory:&tempManuscriptContainingDirExists]) {
        if (![fm createDirectoryAtPath:tempManuscriptContainingDirPath
           withIntermediateDirectories:YES
                            attributes:nil
                                 error:&error]) {
            self.packageAccessError = error;
            return nil;
        }
    }
    else {
        NSAssert(tempManuscriptContainingDirExists, @"Expecting %@ to be a directory if it exists.",
                 tempManuscriptContainingDirPath);
    }
    
    BOOL copyingOriginalSuccessful = [fm copyItemAtPath:_originalBundleFileURL.path toPath:_temporaryManuscriptPath error:&error];
    if (_originalBundleFileURL && !copyingOriginalSuccessful) {
        NSLog(@"ERROR: Failed to copy document bundle from %@ to %@: %@",
              _originalBundleFileURL, _temporaryManuscriptPath, error);
        self.packageAccessError = error;
        return nil;
    }
    
    // if the document didn't yet contain the metadata directory, now's a good time to create it.
    if (copyingOriginalSuccessful) {
        [self initializeManuscriptMetadataDirectoryCreatingDirectory:YES error:&error];
    }
    
    BOOL requiredInitialization = _bundleRequiresInitialization;
    if (_bundleRequiresInitialization) {
        if (![self initializeStateCreatingDirectoryTree:YES error:&error]) {
            NSLog(@"Failed to initialize document bundle directory tree for %@ (%@): %@", _temporaryManuscriptPath, _originalBundleFileURL, error);
            self.packageAccessError = error;
            return nil;
        }
    }
    
    if (![self initializeManuscriptMetadataDirectoryCreatingDirectory:requiredInitialization
                                                                error:&error]) {
        NSLog(@"ERROR: Failed to initialize document metadata directory for document bundle at %@ (%@, %@): %@",
              _temporaryManuscriptPath, _temporaryManuscriptMetadataDirectoryPath, _originalBundleFileURL, error);
        self.packageAccessError = error;
        return nil;
    }
    
    BOOL dirFound = NO;
    
    // chmod u+rw applied to _temporaryManuscriptPath
    if ([fm fileExistsAtPath:_temporaryManuscriptPath isDirectory:&dirFound]
        && ![fm ensurePermissionMaskIncludes:S_IRUSR | S_IWUSR
                                 inDirectory:_temporaryManuscriptPath error:&error]) {
            NSLog(@"ERROR: Failed to set required permissions for bundle at '%@' (%@): %@", _temporaryManuscriptPath, _originalBundleFileURL, error);
            self.packageAccessError = error;
            return nil;
        }
    
    // it's a directory, so needs x too.
    if (dirFound && ![fm ensurePermissionMaskIncludes:S_IEXEC forFileAtPath:_temporaryManuscriptPath error:&error]) {
        NSLog(@"ERROR: Failed to set required permissions for bundle containing directory at '%@': %@", _temporaryManuscriptPath, error);
        return nil;
    }
    
    NSParameterAssert(!self.isLocked);
    
    // can't open in readonly mode because view indices (which to update require write access)
    // may be out of date.
    
    _packageController = [[[self packageControllerClass] alloc] initWithPath:_temporaryManuscriptPath
                                                                    readOnly:NO
                                                                    delegate:self
                                                                       error:&error];
    
    if (!_packageController) {
        NSLog(@"ERROR: Failed to open document at %@ (%@): %@", _temporaryManuscriptPath, _originalBundleFileURL, error);
        self.packageAccessError = error;
        return NO;
    }
    
#ifdef MANUSCRIPTS_APP
    [self postAnonymousUsageInformation];
#endif
    
    self.packageAccessError = nil;
    
    NSError *packageControllerInitError = nil;
    if ([self initializePackageController:_packageController error:&packageControllerInitError]) {
        self.packageAccessError = packageControllerInitError;
    }
        
    return _packageController;
}

- (BOOL)initializePackageController:(MPDatabasePackageController *)packageController error:(NSError **)error {
    return YES; // override
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    if (outError) {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:nil];
    }
    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
    if (outError) {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:nil];
    }
    return NO;
}

+ (BOOL)autosavesInPlace {
    return YES;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    _originalBundleFileURL = absoluteURL;
    return [super readFromURL:absoluteURL ofType:typeName error:outError];
}

- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    if (self.packageAccessError) {
        NSLog(@"Attempting to write document after failure to access document database: %@", self.packageAccessError);
        if (outError) {
            *outError = self.packageAccessError;
        }
        return NO;
    }
    
    if (!_temporaryManuscriptPath) {
        NSLog(@"Attempting to write document with no temporary storage path in place: %@ (%@)", self, self.fileURL);
        if (outError) {
            *outError = [NSError errorWithDomain:MPDatabasePackageBackedDocumentErrorDomain
                                            code:MPDatabasePackageBackedDocumentErrorCodeWorkingPathMissing
                                        userInfo:@{NSLocalizedDescriptionKey:@"Saving document failed because it has been opened in an inconsistent state."}];
        }
        
        return NO;
    }
    
#ifdef DEBUG
    NSParameterAssert(!self.packageAccessError);
    NSParameterAssert(_temporaryManuscriptPath);
#endif
    
    NSLog(@"Writing document to %@", absoluteURL.path);
    
    // initialize the package controller if it already weren't -- this will result in directory structure being created.
    if (!_packageController) {
        _bundleRequiresInitialization = YES;
        if (!self.packageController) {
            if (self.packageAccessError) {
                if (outError) {
                    *outError = [NSError errorWithDomain:MPDatabasePackageBackedDocumentErrorDomain
                                                    code:MPDatabasePackageBackedDocumentErrorCodePackageAccessFailed
                                                userInfo:@{NSLocalizedDescriptionKey:@"Saving document failed because its internal database could not be accessed."}];
                }
                return NO;
            }
            NSAssert(self.packageAccessError,
                     @"Package access error should be set after failure to open a package controller: %@",
                     _temporaryManuscriptPath);
            
            return NO;
        }
        
        NSFileManager *fm = [NSFileManager defaultManager];
        NSParameterAssert([fm fileExistsAtPath:_temporaryManuscriptPath]);
        NSParameterAssert([fm fileExistsAtPath:_temporaryManuscriptMetadataDirectoryPath]);
    }
    
    if (![_packageController saveToURL:absoluteURL error:outError]) {
        return NO;
    }
    
    [self unblockUserInteraction];
    
    return YES;
}

- (BOOL)revertToContentsOfURL:(NSURL *)url
                       ofType:(NSString *)typeName
                        error:(NSError *__autoreleasing *)outError {
    BOOL revert = [super revertToContentsOfURL:url ofType:typeName error:outError];
    
    NSURL *fileURL = self.fileURL;
    
    _reverted = YES;
    
    [NSObject performInMainQueueAfterDelay:.0 block:^{
        [self close];
        [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:fileURL
                                                                               display:YES
                                                                     completionHandler:
         ^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {
             NSLog(@"Opened reverted document %@ at URL %@", document, url);
         }];

    }];
    
    
    return revert;
}

#pragma mark - Window controller

- (Class)mainWindowControllerClass {
    @throw [[MPAbstractMethodException alloc] initWithSelector:_cmd];
}

- (void)makeWindowControllers {
    [self addWindowController:[[[self mainWindowControllerClass] alloc] initWithWindowNibName:@"MPDocument"]];
}

- (id)mainWindowController {
    return self.windowControllers.firstObject;
}

#pragma mark - MPDatabasePackageControllerDelegate

- (NSURL *)packageRootURL {
    return self.fileURL;
}

// Just included for completeness (MPDatabasePackageControllerDelegate protocol requires this same method)
- (void)updateChangeCount:(NSDocumentChangeType)change {
    // needs to be called on main queue as it can lead to autolayout work.
    dispatch_async(dispatch_get_main_queue(), ^{
        [super updateChangeCount:change];
    });
}

#pragma mark - Scriptability

/*
 - (NSScriptObjectSpecifier *)objectSpecifier {
 NSScriptObjectSpecifier *appObjSpec = [[NSApplication sharedApplication] objectSpecifier];
 return [[NSIndexSpecifier alloc] initWithContainerClassDescription:appObjSpec.keyClassDescription
 containerSpecifier:appObjSpec
 key:@"orderedDocuments"
 index:[NSApplication.sharedApplication.orderedDocuments indexOfObject:self]];
 }
 */

- (id)scriptingValueForSpecifier:(NSScriptObjectSpecifier *)objectSpecifier {
    return [super scriptingValueForSpecifier:objectSpecifier];
}

- (id)valueInPackageControllerWithUniqueID:(NSString *)uniqueID {
    assert([[self.packageController identifier] isEqualToString:uniqueID]);
    if ([[self.packageController identifier] isEqualToString:uniqueID])
        return self.packageController;
    return nil;
}

@end


#pragma mark - Scripting package controller adapter

@implementation MPSharedPackageControllerAdapter

- (instancetype)initWithContainer:(MPDatabasePackageBackedDocument *)document sharedPackageController:(MPShoeboxPackageController *)spkg {
    self = [super init];
    
    if (self) {
        _sharedPackageController = spkg;
        _document = document;
    }
    
    return self;
}

- (NSScriptObjectSpecifier *)objectSpecifier {
    id parentSpec = [self.document objectSpecifier];
    assert(parentSpec);
    id parentClassSpec = [parentSpec keyClassDescription];
    assert(parentClassSpec);
    
    return [[NSPropertySpecifier alloc] initWithContainerClassDescription:parentClassSpec
                                                       containerSpecifier:parentSpec
                                                                      key:@"sharedPackageControllerAdapter"];
}

@end