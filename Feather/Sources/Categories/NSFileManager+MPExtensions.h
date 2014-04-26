//
//  NSFileManager+MPExtensions.h
//  Feather
//
//  Created by Matias Piipari on 29/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, MPFileTargetErrorCode)
{
    MPFileTargetErrorCodeUnknown = 0,
    MPFileTargetErrorCodeFailedToDetermineMimeType = 1
};

@interface NSFileManager (MPExtensions)

@property (readonly, copy) NSString *applicationSupportFolder;

- (NSString *)md5DigestStringAtPath:(NSString *)path;

#ifdef MP_FEATHER_OSX
- (NSString *)mimeTypeForFileAtURL:(NSURL *)url error:(NSError **)err;
#endif

- (NSURL *)temporaryDirectoryURLInApplicationCachesSubdirectoryNamed:(NSString *)subdirectoryName
                                                               error:(NSError *__autoreleasing *)outError;


- (NSURL *)temporaryFileURLInApplicationCachesSubdirectoryNamed:(NSString *)subdirectoryName
                                                  withExtension:(NSString *)pathExtension
                                                          error:(NSError *__autoreleasing *)outError;

- (NSURL *)URLForApplicationSupportDirectoryNamed:(NSString *)subpath;


@end
