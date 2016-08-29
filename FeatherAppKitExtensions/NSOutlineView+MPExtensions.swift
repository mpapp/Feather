//
//  NSOutlineView+MPExtensions.swift
//  Feather
//
//  Created by Matias Piipari on 27/08/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

public extension NSOutlineView {
    public var allSelectedItems:[AnyObject] {
        return self.selectedRowIndexes.flatMap { index in
            return self.itemAtRow(index)
        }
    }
    
    public func selectItem(item:AnyObject?, byExtendingSelection:Bool) {
        if (!byExtendingSelection) {
            self.deselectAll(self)
        }
        
        let row = self.rowForItem(item)
        if row < 0 {
            return
        }
        
        self.selectRowIndexes(NSIndexSet(index:row), byExtendingSelection: true)
    }
    
    public func selectItems(items:[AnyObject], byExtendingSelection:Bool) {
        if (!byExtendingSelection) {
            self.deselectAll(self)
        }
        
        for item in items {
            self.selectItem(item, byExtendingSelection: true)
        }
    }
}
