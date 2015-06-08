//
//  MPTreeItemUtility.h
//  Feather
//
//  Created by Matias Piipari on 07/06/2015.
//  Copyright (c) 2015 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MPTreeItem;

@interface MPTreeItemUtility : NSObject

+ (NSArray *)descendentsForTreeItem:(id<MPTreeItem>)treeItem;

@end
