//
//  MPTreeItemUtility.m
//  Feather
//
//  Created by Matias Piipari on 07/06/2015.
//  Copyright (c) 2015 Matias Piipari. All rights reserved.
//

#import "MPTreeItemUtility.h"
#import <Feather/MPTreeItem.h>

@implementation MPTreeItemUtility

+ (NSArray *)descendentsForTreeItem:(id<MPTreeItem>)treeItem {
    NSMutableArray *treeItems = [NSMutableArray new];
    
    NSMutableArray *stack = [NSMutableArray new];
    
    for (id<MPTreeItem> child in [treeItem children]) {
        [treeItems addObject:child];
        [stack addObject:child];
        
        while (stack.count > 0) {
            id<MPTreeItem> last = [stack lastObject];
            [treeItems addObject:last];
            [stack removeLastObject];
            
            for (id<MPTreeItem> c in [last children]) {
                [stack addObject:c];
            }
        }
    }
    
    return treeItems.copy;
}

@end
