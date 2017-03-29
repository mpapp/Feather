//
//  NSArray+MPExtensions.swift
//  Feather
//
//  Created by Matias Piipari on 05/03/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

public extension NSArray {
    public var uniqueValues: NSArray {
        return NSOrderedSet(array: self as [AnyObject]).array as NSArray
    }
        
    public func containsAny(ofObjects objects:[AnyObject]) -> Bool {
        let setSelf = NSSet(array:self as [AnyObject])
        
        for o in objects {
            if setSelf.contains(o) {
                return true
            }
        }
        
        return false
    }
}
