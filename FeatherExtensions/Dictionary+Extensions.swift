//
//  Dictionary+Extensions.swift
//  Feather
//
//  Created by Matias Piipari on 07/07/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

public extension Dictionary {
    
    init(withPairs pairs:[(Key, Value)]) {
        self.init()
        for pair in pairs {
            self[pair.0] = pair.1
        }
    }
    
}

public extension Dictionary where Value: Hashable {
    
    func inverted() -> [Value: Key] {
        var dict = [Value:Key]()
        for (key, value) in self {
            dict[value] = key
        }
        return dict
    }
    
}

@objc public extension NSDictionary {
    @objc func invertedDictionary() -> NSDictionary {
        let dict = NSMutableDictionary()
        
        for key in self.allKeys {
            let value = self.object(forKey: key)!
            
            guard let copyableValue = value as? NSCopying else {
                preconditionFailure("Value \(value) (of type \(type(of: (value) as AnyObject))) does not conform to NSCopying.")
            }
            dict[copyableValue] = key
        }
        
        return dict
    }
}
