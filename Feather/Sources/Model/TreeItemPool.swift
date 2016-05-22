//
//  TreeItemPool.swift
//  Feather
//
//  Created by Matias Piipari on 19/05/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

@objc public final class TreeItemPool: NSObject {
    
    private var items = [String:MPTreeItem]()
    
    // exchanges the incoming item for an existing item with the same fully qualified identifier, or returns the same item.
    // for virtual sections such as root sections and object wrapping sections, you should no longer point at the item you passed to item(forItem:…) in the method where you did so. 
    public func item(forItem item:MPTreeItem) -> MPTreeItem {
        let existingItem = items[fullyQualifiedIdentifier(treeItem:item)]
        if let existingItem = existingItem {
            return existingItem
        }
        
        self.items[fullyQualifiedIdentifier(treeItem: item)] = item
        return item
    }
    
    public func fullyQualifiedIdentifier(treeItem item:MPTreeItem) -> String {
        if let parent = item.parent {
            guard let parentID = parent.identifier else {
                preconditionFailure("Parent must be identifiable: \(parent)")
            }
            return "\(parentID)/\(item.identifier)"
        }
        else {
            guard let identifier = item.identifier else {
                preconditionFailure("Item \(item) is not not identifiable.")
            }
            return identifier
        }
    }
}