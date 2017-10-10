//
//  NSArray+MPExtensions.swift
//  Feather
//
//  Created by Matias Piipari on 05/03/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

@objc public extension NSArray {
    
    @objc public var uniqueValues: [AnyObject] {
        return NSOrderedSet(array: self as [AnyObject]).array as [AnyObject]
    }
        
    @objc public func containsAny(ofObjects objects:[AnyObject]) -> Bool {
        let setSelf = NSSet(array:self as [AnyObject])
        
        for o in objects {
            if setSelf.contains(o) {
                return true
            }
        }
        
        return false
    }
    
}
