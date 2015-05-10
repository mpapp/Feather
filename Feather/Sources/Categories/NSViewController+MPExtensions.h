//
//  NSViewController+MPExtensions.h
//  Manuscripts
//
//  Created by Markus on 2/5/13.
//  Copyright (c) 2013-2015 Manuscripts.app Limited. All rights reserved.
//


#import <Cocoa/Cocoa.h>


@interface NSViewController (MPExtensions)

+ (instancetype)viewControllerOfClass:(Class)viewControllerClass withNibNamed:(NSString *)nibName;

@end
