//
//  NSTextView+MPExtensions.h
//  Manuscripts
//
//  Created by Matias Piipari on 21/04/2014.
//  Copyright (c) 2014-2015 Manuscripts.app Limited. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSTextView (MPExtensions)

@property (readonly) NSUInteger wrappedLineCount;

@property (readonly) NSUInteger hardLineFeedCount;

@end
