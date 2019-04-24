//
//  CollectionType+MPExtensions.swift
//  Feather
//
//  Created by Matias Piipari on 20/02/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

public extension Collection {

    func chunks(withDistance distance: Int) -> [[SubSequence.Iterator.Element]] {
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

public extension Collection where Indices.Iterator.Element == Index {

    /// Safely subscript a `Collection`. Returns either the object at the given index, or `nil` if the index would
    /// otherwise cause an out-of-bounds exception.
    ///
    /// - Parameter index: The integer index of the object in the `Collection` to return.
    subscript (ifExists index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
