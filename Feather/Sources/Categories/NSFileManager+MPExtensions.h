//
//  NSFileManager+MPExtensions.h
//  Feather
//
//  Created by Matias Piipari on 29/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSUInteger, MPFileTargetErrorCode)
{
    MPFileTargetErrorCodeUnknown = 0,
    MPFileTargetErrorCodeFailedToDetermineMimeType = 1
};


extern NSString * __nonnull const MPFeatherNSFileManagerExtensionsErrorDomain;

extern NS_ENUM(NSUInteger, MPFeatherNSFileManagerExtensionsErrorCode) {
    MPFeatherNSFileManagerExtensionsErrorCodeUnknown = 0,
    MPFeatherNSFileManagerExtensionsErrorCodeCannotDetermineCachesDirectory = 1,
    MPFeatherNSFileManagerExtensionsErrorCodeCachesExistsButNotDirectory = 2,
    MPFeatherNSFileManagerExtensionsErrorCodeFailedToCreateCachesDirectory = 3,
    MPFeatherNSFileManagerExtensionsErrorCodeFailedToCreateTempDirectory = 4,
    MPFeatherNSFileManagerExtensionsErrorCodeXAttrRemovalFailed = 5
};

@interface NSFileManager (MPExtensions)

@property (readonly, copy, nullable) NSString *applicationSupportFolder;

- (nullable NSString *)md5DigestStringAtPath:(nonnull NSString *)path;

- (nullable NSString *)mimeTypeForFileAtURL:(nonnull NSURL *)url error:(NSError *_Nullable *_Nullable)err;

- (nullable NSURL *)temporaryDirectoryURLInApplicationCachesSubdirectoryNamed:(nullable NSString *)subdirectoryName
                                                                        error:(NSError *_Nullable *_Nullable)outError;


- (nullable NSURL *)temporaryFileURLInApplicationCachesSubdirectoryNamed:(nullable NSString *)subdirectoryName
                                                           withExtension:(nonnull NSString *)pathExtension
                                                                   error:(NSError *_Nullable *_Nullable)outError;

- (nullable NSURL *)temporaryDirectoryURLInGroupCachesSubdirectoryNamed:(nonnull NSString *)subdirectoryName error:(NSError *_Nonnull *_Nonnull)outError;
- (nullable NSURL *)temporaryFileURLInGroupCachesSubdirectoryNamed:(nonnull NSString *)subdirectoryName withExtension:(nonnull NSString *)pathExtension error:(NSError *_Nonnull *_Nonnull)err;

- (nullable NSURL *)sharedApplicationGroupCachesDirectoryURL;

- (nullable NSURL *)sharedApplicationGroupSupportDirectoryURL;

- (nullable NSURL *)URLForApplicationSupportDirectoryNamed:(nonnull NSString *)subpath;

/** Returns absolute paths to paths for resources of given type inside directory. If type is nil, all files are listed. */
- (nonnull NSArray *)recursivePathsForResourcesOfType:(nullable NSString *)type inDirectory:(nonnull NSString *)directoryPath;

/** Ensures that all files under the specified directory (with limitless recursion) will receive the specified permission mask (mask applied with | so including set bits are spared). */
- (BOOL)ensurePermissionMaskIncludes:(int)grantedMask inDirectory:(nonnull NSString *)directoryPath error:(NSError *_Nullable *_Nullable)error;

/** Ensures that the file at the specified path will receive the specified permission mask (mask applied with | so including set bits are spared). */
- (BOOL)ensurePermissionMaskIncludes:(int)grantedMask forFileAtPath:(nonnull NSString *)path error:(NSError *_Nullable *_Nullable)error;

/** Release the file at the specified root path from quarantine.
  * In case of a directory, un-quarantines also any contained files and subdirectories (recursively). */
- (BOOL)releaseFromQuarantine:(nonnull NSString *)root error:(NSError *_Nullable *_Nullable)error;

/** Return YES if pathA and pathB point at the same file (resolves alias / link, check match to inode number), and return NO and an error if either path attributes fail to be resolved. */
- (BOOL)path:(nonnull NSString *)pathA isEqualToPath:(nonnull NSString *)pathB error:(NSError *_Nullable *_Nullable)err;

/** Returns a security scoped URL that the application has begun accessing, if successful, and nil and an error otherwise.*/
- (nullable NSURL *)beginSecurityScopedAccessForPath:(nonnull NSString *)path bookmarkUserDefaultKey:(nonnull NSString *)bookmarkUserDefaultKey error:(NSError *_Nullable *_Nullable)error;

+ (nullable NSString *)UTIForPathExtension:(nonnull NSString *)extension;

@end
