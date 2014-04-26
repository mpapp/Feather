//
//  MPThumbnailable.h
//  Feather
//
//  Created by Matias Piipari on 27/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef MP_FEATHER_IOS
#import <UIKit/UIKit.h>
@compatibility_alias NSImage UIImage;
#endif

@protocol MPThumbnailable <NSObject>

@property (readonly, strong) NSImage *thumbnailImage;

@end
