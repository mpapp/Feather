//
//  NSAttributedString+MPExtensions.swift
//  Feather
//
//  Created by Matias Piipari on 12/06/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

public extension NSAttributedString {
    func components(separatedBy string:String) -> [NSAttributedString] {
        let strRep = self.string

        let separatedArray = strRep.components(separatedBy:string)
        
        var start = 0
        return separatedArray.map { sub in
            let range = NSMakeRange(start, (sub as NSString).length)
            
            let str = self.attributedSubstring(from: range)
            start += range.length + (string as NSString).length
            
            return str
        }
    }
}
