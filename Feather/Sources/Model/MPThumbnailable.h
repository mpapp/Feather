//
//  MPThumbnailable.h
//  Feather
//
//  Created by Matias Piipari on 27/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MPThumbnailable <NSObject>

@property (readonly, strong, nonnull) NSImage *thumbnailImage;

@end
