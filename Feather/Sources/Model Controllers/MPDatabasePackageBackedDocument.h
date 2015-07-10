//
//  MPDatabasePackageBackedDocument.h
//  Feather
//
//  Created by Matias Piipari on 10/07/2015.
//  Copyright (c) 2015 Matias Piipari. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MPDatabasePackageBackedDocument : NSDocument

/** YES if package access should not be permitted, NO if package access is permitted. */
@property (readwrite) BOOL packageAccessDenied;

@end
