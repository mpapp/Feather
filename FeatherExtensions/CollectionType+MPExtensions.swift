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
    
}