//
//  NSOutlineView+MPExtensions.swift
//  Feather
//
//  Created by Matias Piipari on 27/08/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

public extension NSOutlineView {
    @objc var allSelectedItems:[Any] {
        return self.selectedRowIndexes.compactMap { index in
            return self.item(atRow: index)
        }
    }
    
    @objc(selectItem:byExtendingSelection:) func select(item:Any?, byExtendingSelection:Bool) {
        if (!byExtendingSelection) {
            self.deselectAll(self)
        }
        
        let row = self.row(forItem: item)
        if row < 0 {
            return
        }
        
        self.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
    }
    
    @objc(selectItems:byExtendingSelection:) func select(items:[Any]?, byExtendingSelection:Bool) {
        if (!byExtendingSelection || items == nil) {
            self.deselectAll(self)
        }
        
        guard let nonNilItems = items else {
            return
        }
        
        for item in nonNilItems {
            self.select(item: item, byExtendingSelection: true)
        }
    }
}
