//
//  String+Extensions.swift
//  Feather
//
//  Created by Matias Piipari on 18/05/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation
import RegexKitLite

public extension String {
    public func stringAroundOccurrence(ofString str:String, maxPadding:UInt, options:NSStringCompareOptions = []) -> String? {
        guard let range = self.rangeOfString(str, options:options, range: nil, locale: nil) else {
            return nil
        }
        
        let p = Int(maxPadding)
        let r = range.startIndex.advancedBy(-p, limit: self.startIndex) ..< range.endIndex.advancedBy(p, limit: self.endIndex)
        return self.substringWithRange(r)
    }
    
    public enum LinkRelationParsingError: ErrorType {
        case EmptyString
        case UnexpectedSection([String])
    }
    
    public func linkRelations() throws -> [String:String] {
        if self.isEmpty {
            throw LinkRelationParsingError.EmptyString
        }
        
        var links = [String:String]()
        for part in self.componentsSeparatedByString(",") {
            let section = part.componentsSeparatedByString(";")
            
            if section.count != 2 {
                throw LinkRelationParsingError.UnexpectedSection(section)
            }
            
            let url = (section[0] as NSString).stringByReplacingOccurrencesOfRegex("<(.*)>", withString: "$1")
            let name = (section[1] as NSString).stringByReplacingOccurrencesOfRegex("\\s+rel=\"(.*)\"", withString: "$1")
            links[name] = url
        }
        
        return links
    }
}