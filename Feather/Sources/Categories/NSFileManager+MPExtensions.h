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


extern NSString * const MPFeatherNSFileManagerExtensionsErrorDomain;

extern NS_ENUM(NSUInteger, MPFeatherNSFileManagerExtensionsErrorCode) {
    MPFeatherNSFileManagerExtensionsErrorCodeUnknown = 0,
    MPFeatherNSFileManagerExtensionsErrorCodeCannotDetermineCachesDirectory = 1,
    MPFeatherNSFileManagerExtensionsErrorCodeCachesExistsButNotDirectory = 2,
    MPFeatherNSFileManagerExtensionsErrorCodeFailedToCreateCachesDirectory = 3,
    MPFeatherNSFileManagerExtensionsErrorCodeFailedToCreateTempDirectory = 4,
    MPFeatherNSFileManagerExtensionsErrorCodeXAttrRemovalFailed = 5
};

@interface NSFileManager (MPExtensions)

@property (readonly, copy) NSString *applicationSupportFolder;

- (NSString *)md5DigestStringAtPath:(NSString *)path;

- (NSString *)mimeTypeForFileAtURL:(NSURL *)url error:(NSError **)err;

- (NSURL *)temporaryDirectoryURLInApplicationCachesSubdirectoryNamed:(NSString *)subdirectoryName
                                                               error:(NSError *__autoreleasing *)outError;


- (NSURL *)temporaryFileURLInApplicationCachesSubdirectoryNamed:(NSString *)subdirectoryName
                                                  withExtension:(NSString *)pathExtension
                                                          error:(NSError *__autoreleasing *)outError;

- (NSURL *)temporaryDirectoryURLInGroupCachesSubdirectoryNamed:(NSString *)subdirectoryName error:(NSError *__autoreleasing *)outError;
- (NSURL *)temporaryFileURLInGroupCachesSubdirectoryNamed:(NSString *)subdirectoryName withExtension:(NSString *)pathExtension error:(NSError *__autoreleasing *)err;

- (NSURL *)sharedApplicationGroupCachesDirectoryURL;

- (NSURL *)sharedApplicationGroupSupportDirectoryURL;

- (NSURL *)URLForApplicationSupportDirectoryNamed:(NSString *)subpath;

/** Returns absolute paths to paths for resources of given type inside directory. If type is nil, all files are listed. */
- (NSArray *)recursivePathsForResourcesOfType:(NSString *)type inDirectory:(NSString *)directoryPath;

/** Ensures that all files under the specified directory (with limitless recursion) will receive the specified permission mask (mask applied with | so including set bits are spared). */
- (BOOL)ensurePermissionMaskIncludes:(int)grantedMask inDirectory:(NSString *)directoryPath error:(NSError **)error;

/** Release the file at the specified root path from quarantine.
  * In case of a directory, un-quarantines also any contained files and subdirectories (recursively). */
- (BOOL)releaseFromQuarantine:(NSString *)root error:(NSError **)error;

/** Return YES if pathA and pathB point at the same file (resolves alias / link, check match to inode number), and return NO and an error if either path attributes fail to be resolved. */
- (BOOL)path:(NSString *)pathA isEqualToPath:(NSString *)pathB error:(NSError **)err;

/** Returns a security scoped URL that the application has begun accessing, if successful, and nil and an error otherwise.*/
- (NSURL *)beginSecurityScopedAccessForPath:(NSString *)path bookmarkUserDefaultKey:(NSString *)bookmarkUserDefaultKey error:(NSError **)error;

+ (NSString *)UTIForPathExtension:(NSString *)extension;

@end
