//
//  NSAppleScriptDescript+MPExtensions.swift
//  Feather
//
//  Created by Matias Piipari on 30/04/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

enum AppleEventConversionError:ErrorType {
    case UnexpectedDescriptorType(NSAppleEventDescriptor?)
}

public extension NSAppleEventDescriptor {
    
    // from https://github.com/yangyubo/AppleScriptToolkit/blob/master/NSAppleEventDescriptor%2BArray.m
    func arrayValue() throws -> [AnyObject] {
        var count = self.numberOfItems
        
        var workingDesc = self
        if count == 0 {
            if let d = self.coerceToDescriptorType(unsafeBitCast(typeAEList, DescType.self)) {
                workingDesc = d
                count = workingDesc.numberOfItems
            }
        }
        
        let items = try (1...count).map { i -> AnyObject in
            let desc = workingDesc.descriptorAtIndex(i)
            
            guard let value = desc?.objectSpecifier?.objectsByEvaluatingSpecifier else {
                throw AppleEventConversionError.UnexpectedDescriptorType(desc)
            }
            
            return value
        }

        return items
    }
}