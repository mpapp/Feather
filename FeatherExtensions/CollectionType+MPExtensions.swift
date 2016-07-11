//
//  CollectionType+MPExtensions.swift
//  Feather
//
//  Created by Matias Piipari on 20/02/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

public extension CollectionType {
    
    @warn_unused_result
    public func first(@noescape predicate: (Self.Generator.Element) throws -> Bool) rethrows -> Self.Generator.Element? {
        for e in self {
            if try predicate(e) {
                return e
            }
        }
        return nil
    }
    
    @warn_unused_result
    func chunks(withDistance distance: Index.Distance) -> [[SubSequence.Generator.Element]] {
        var index = startIndex
        let generator: AnyGenerator<Array<SubSequence.Generator.Element>> = AnyGenerator {
            defer { index = index.advancedBy(distance, limit: self.endIndex) }
            return index != self.endIndex ? Array(self[index ..< index.advancedBy(distance, limit: self.endIndex)]) : nil
        }
        return Array(generator)
    }
    
}
