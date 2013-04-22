//
//  MPBundlable.h
//  Manuscripts
//
//  Created by Matias Piipari on 24/02/2013.
//  Copyright (c) 2013 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MPBundlable <NSObject>
@optional
@property (readwrite) BOOL bundled;
@end

@interface MPBundlableMixin : NSObject <MPBundlable>
@end
