//
//  MPCategorizableMixin.h
//  Manuscripts
//
//  Created by Matias Piipari on 17/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Feather/Feather.h>

#import "MPBundlableMixin.h"

@protocol MPCategorizable <NSObject, MPBundlable, MPReferencableObject>
@optional
@property (readwrite, copy) NSString *name;
@property (readwrite, copy) NSString *desc;

/** Determines the default sort order of the category. */
@property (readwrite) NSInteger priority;
@end

typedef NSComparisonResult (^MPSortByPriorityBlock)(id<MPCategorizable> a, id<MPCategorizable> b);

@interface MPCategorizableMixin : NSObject

+ (MPSortByPriorityBlock)sortByPriorityBlock;

@end
