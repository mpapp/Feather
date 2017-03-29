//
//  CollectionType+MPExtensions.swift
//  Feather
//
//  Created by Matias Piipari on 20/02/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

public extension Collection {
    
    public func first(predicate: (Self.Iterator.Element) throws -> Bool) rethrows -> Self.Iterator.Element? {
        for e in self {
            if try predicate(e) {
                return e
            }
        }
        return nil
    }
    
    
    func chunks(withDistance distance: IndexDistance) -> [[SubSequence.Iterator.Element]] {
        var index = startIndex
        let iterator: AnyIterator<Array<SubSequence.Iterator.Element>> = AnyIterator {
            defer { index = self.index(index, offsetBy: distance, limitedBy: self.endIndex) ?? self.endIndex }
            return index != self.endIndex
                    ? Array(self[index
                            ..<
                            (self.index(index, offsetBy: distance, limitedBy: self.endIndex) ?? self.endIndex) ])
                    : nil
        }
        return Array(iterator)
    }
    
}
