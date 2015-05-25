//
//  NSFileManager+MPExtensions.m
//  Feather
//
//  Created by Matias Piipari on 29/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "NSFileManager+MPExtensions.h"
#import "NSError+MPExtensions.h"
#import "NSString+MPExtensions.h"
#import "NSData+MPExtensions.h"
#import "NSBundle+MPExtensions.h"

#import <CommonCrypto/CommonDigest.h>

#include <dlfcn.h>
#include <errno.h>

#include <sys/xattr.h>

NSString * const MPFeatherNSFileManagerExtensionsErrorDomain = @"MPFeatherNSFileManagerExtensionsErrorDomain";

@implementation NSFileManager (MPExtensions)

- (NSString *)applicationSupportFolder
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                         NSUserDomainMask, YES);
    NSString *path = paths[0];
    return path;
}

- (NSString *)md5DigestStringAtPath:(NSString *)path
{
	BOOL isDir;
	if (path && [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && !isDir)
	{
		NSError *err = nil;
		NSData *data = [NSData dataWithContentsOfFile:path options:NSMappedRead error:&err];
		if (data) return [data md5DigestString];
	}
	return nil;
}

- (NSString *)mimeTypeForFileAtURL:(NSURL *)url error:(NSError **)err
{
    NSString *type = [[NSWorkspace sharedWorkspace] typeOfFile:[url path] error:err];
    if (!type) return nil;
    
    CFStringRef mimeType = UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)type, kUTTagClassMIMEType);
    return (__bridge_transfer NSString *)mimeType;
}

- (NSURL *)sharedApplicationGroupCachesDirectoryURL
{
    NSString *groupIdentifier = [[NSBundle appBundle] objectForInfoDictionaryKey:@"MPSharedApplicationSecurityGroupIdentifier"];
    NSAssert(groupIdentifier, @"Must set key 'MPSharedApplicationSecurityGroupIdentifier' in Info.plist (even if not sandboxed)"); // Shared security group identifier must be set in Info.plist
    
    NSURL *groupContainerURL = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:groupIdentifier];
    NSURL *cachesDirectoryURL = [groupContainerURL URLByAppendingPathComponent:@"Library/Caches"];
    return cachesDirectoryURL;
}

- (NSURL *)temporaryDirectoryURLInApplicationCachesSubdirectoryNamed:(NSString *)subdirectoryName error:(NSError *__autoreleasing *)outError
{
    return [self temporaryURLInApplicationCachesSubdirectoryNamed:subdirectoryName createDirectory:YES extension:@"" error:outError];
}

- (NSURL *)temporaryFileURLInApplicationCachesSubdirectoryNamed:(NSString *)subdirectoryName withExtension:(NSString *)pathExtension error:(NSError *__autoreleasing *)outError
{
    return [self temporaryURLInApplicationCachesSubdirectoryNamed:subdirectoryName createDirectory:NO extension:pathExtension error:outError];
}

- (NSURL *)temporaryURLInApplicationCachesSubdirectoryNamed:(NSString *)subdirectoryName
                                            createDirectory:(BOOL)createDirectory
                                                  extension:(NSString *)pathExtension
                                                      error:(NSError *__autoreleasing *)outError
{
    NSError *error;
    NSURL *cachesRootDirectoryURL = [self URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
    
    if (cachesRootDirectoryURL == nil)
    {
        if (outError != NULL)
        {
            *outError = [NSError errorWithDomain:MPFeatherNSFileManagerExtensionsErrorDomain
                                            code:MPFeatherNSFileManagerExtensionsErrorCodeCannotDetermineCachesDirectory
                                     description:@"Failed to determine user caches directory"
                                 underlyingError:error];
        }
        return nil;
    }
    
    NSURL *applicationCachesDirectoryURL
        = [cachesRootDirectoryURL URLByAppendingPathComponent:NSBundle.appBundle.bundleIdentifier];
    BOOL createIntermediates = (subdirectoryName.length > 0);
    NSURL *URL = createIntermediates ? [applicationCachesDirectoryURL URLByAppendingPathComponent:subdirectoryName] : applicationCachesDirectoryURL;
    
    BOOL isDirectory, exists = [self fileExistsAtPath:URL.path isDirectory:&isDirectory];
    
    if (exists && !isDirectory)
    {
        if (outError != NULL)
        {
            *outError = [NSError errorWithDomain:MPFeatherNSFileManagerExtensionsErrorDomain
                                            code:MPFeatherNSFileManagerExtensionsErrorCodeCachesExistsButNotDirectory
                                     description:MPStringF(@"Cannot use application caches directory at %@", applicationCachesDirectoryURL.path)
                                          reason:MPStringF(@"File at %@ exists but is not a directory", applicationCachesDirectoryURL.path)];
        }
        return nil;
    }
    else if (!exists)
    {
        
        BOOL success = [self createDirectoryAtURL:URL withIntermediateDirectories:createIntermediates attributes:nil error:&error];
        
        if (!success) {
            if (outError != NULL)
            {
                *outError = [NSError errorWithDomain:MPFeatherNSFileManagerExtensionsErrorDomain
                                                code:MPFeatherNSFileManagerExtensionsErrorCodeFailedToCreateCachesDirectory
                                         description:MPStringF(@"Failed to create application caches directory at %@", URL.path)
                                     underlyingError:error];
            }
            return nil;
        }
    }
    
    NSURL *temporaryURL;
    NSUInteger i = 0;
    NSString *ext = (pathExtension.length > 0) ? MPStringF(@".%@", pathExtension) : @"";
    
    do
    {
        NSString *s = [[[NSProcessInfo processInfo] globallyUniqueString] substringToIndex:8];
        
        if (i == 0)
        {
            temporaryURL = [URL URLByAppendingPathComponent:MPStringF(@"%@%@", s, ext)];
        }
        else
        {
            temporaryURL = [URL URLByAppendingPathComponent:MPStringF(@"%@_%li%@", s, i, ext)];
        }
    }
    while ([self fileExistsAtPath:temporaryURL.path]);
    
    if (createDirectory)
    {
        BOOL success = [self createDirectoryAtURL:temporaryURL withIntermediateDirectories:NO attributes:nil error:&error];
        
        if (!success)
        {
            if (outError != nil)
            {
                *outError = [NSError errorWithDomain:MPFeatherNSFileManagerExtensionsErrorDomain
                                                code:MPFeatherNSFileManagerExtensionsErrorCodeFailedToCreateTempDirectory
                                         description:MPStringF(@"Failed to create temporary directory at %@", temporaryURL)
                                     underlyingError:error];
            }
            return nil;
        }
    }
    
    return temporaryURL;
}

- (NSURL *)URLForApplicationSupportDirectoryNamed:(NSString *)subpath
{
    NSURL *URL = [self URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
    if (subpath)
        URL = [URL URLByAppendingPathComponent:subpath isDirectory:YES];
    return URL;
}

// taken from http://stackoverflow.com/questions/5836587/how-do-i-get-all-resource-paths-in-my-bundle-recursively-in-ios
- (NSArray *)recursivePathsForResourcesOfType:(NSString *)type inDirectory:(NSString *)directoryPath {
    
    NSMutableArray *filePaths = [NSMutableArray new];
    
    // Enumerators are recursive
    NSDirectoryEnumerator *enumerator = [self enumeratorAtPath:directoryPath];
    
    NSString *filePath;
    
    while ((filePath = [enumerator nextObject]) != nil) {
        
        // If we have the right type of file, add it to the list
        // Make sure to prepend the directory path
        if ([[filePath pathExtension] isEqualToString:type] || !type) {
            [filePaths addObject:[directoryPath stringByAppendingPathComponent:filePath]];
        }
    }
    
    return filePaths.copy;
}

- (BOOL)ensurePermissionMaskIncludes:(int)grantedMask inDirectory:(NSString *)directoryPath error:(NSError **)error {
    for (NSString *path in [self recursivePathsForResourcesOfType:nil inDirectory:directoryPath]) {
        NSDictionary *attribs = [self attributesOfItemAtPath:path error:error];
        
        if (!attribs) {
            return NO;
        }
        
        int permissions = [attribs[NSFilePosixPermissions] intValue];
        permissions |= grantedMask;
        
        NSMutableDictionary *newAttribs = [attribs mutableCopy];
        newAttribs[NSFilePosixPermissions] = @(permissions);
        
        if (![self setAttributes:newAttribs.copy ofItemAtPath:path error:error]) {
            return NO;
        }
    }
    
    return YES;
}

// from https://github.com/jrmuizel/mozilla-cvs-history/blob/master/camino/sparkle/NSFileManager%2BExtendedAttributes.m

- (int)removeXAttr:(const char*)name
          fromFile:(NSString*)file
           options:(int)options
{
    typedef int (*removexattr_type)(const char*, const char*, int);

    // Reference removexattr directly, it's in the SDK.
    static removexattr_type removexattr_func = removexattr;
    
    const char* path = NULL;
    @try {
        path = [file fileSystemRepresentation];
    }
    @catch (id exception) {
        // -[NSString fileSystemRepresentation] throws an exception if it's
        // unable to convert the string to something suitable.  Map that to
        // EDOM, "argument out of domain", which sort of conveys that there
        // was a conversion failure.
        errno = EDOM;
        return -1;
    }
    
    return removexattr_func(path, name, options);
}

- (void)releaseFromQuarantine:(NSString*)root
{
    const char* quarantineAttribute = "com.apple.quarantine";
    const int removeXAttrOptions = XATTR_NOFOLLOW;
    
    [self removeXAttr:quarantineAttribute
             fromFile:root
              options:removeXAttrOptions];
    
    // Only recurse if it's actually a directory.  Don't recurse into a
    // root-level symbolic link.
    NSError *err = nil;
    
    NSDictionary* rootAttributes = [self attributesOfItemAtPath:root error:&err];
    if (!rootAttributes) {
        NSLog(@"ERROR: %@", err);
        return;
    }
    
    NSString* rootType = [rootAttributes objectForKey:NSFileType];
    
    if (rootType == NSFileTypeDirectory) {
        // The NSDirectoryEnumerator will avoid recursing into any contained
        // symbolic links, so no further type checks are needed.
        NSDirectoryEnumerator* directoryEnumerator = [self enumeratorAtPath:root];
        NSString* file = nil;
        while ((file = [directoryEnumerator nextObject])) {
            [self removeXAttr:quarantineAttribute
                     fromFile:[root stringByAppendingPathComponent:file]
                      options:removeXAttrOptions];
        }
    }
}


@end
