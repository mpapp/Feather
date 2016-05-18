//
//  String+Extensions.swift
//  Feather
//
//  Created by Matias Piipari on 18/05/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

public extension String {
    public func stringAroundOccurrence(ofString str:String, maxPadding:UInt, options:NSStringCompareOptions = []) -> String? {
        guard let range = self.rangeOfString(str, options:options, range: nil, locale: nil) else {
            return nil
        }
        
        let p = Int(maxPadding)
        let r = range.startIndex.advancedBy(-p, limit: self.startIndex) ..< range.endIndex.advancedBy(p, limit: self.endIndex)
        return self.substringWithRange(r)
    }
}