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
