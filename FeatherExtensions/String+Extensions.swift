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
    public func stringAroundOccurrence(ofString str:String, maxPadding:UInt, options:NSString.CompareOptions = []) -> String? {
        guard let range = self.range(of: str, options:options, range: nil, locale: nil) else {
            return nil
        }
        
        let charView = self.characters
        let p = Int(maxPadding)
        let r = (charView.index(range.lowerBound, offsetBy: -p, limitedBy: self.startIndex) ?? charView.startIndex)
                ..<
                (charView.index(range.upperBound, offsetBy: p, limitedBy: self.endIndex) ?? charView.endIndex)
        
        return self.substring(with: r)
    }
    
    public enum LinkRelationParsingError: Error {
        case emptyString
        case unexpectedSection([String])
    }
    
    public func linkRelations() throws -> [String:String] {
        if self.isEmpty {
            throw LinkRelationParsingError.emptyString
        }
        
        var links = [String:String]()
        for part in self.components(separatedBy: ",") {
            let section = part.components(separatedBy: ";")
            
            if section.count != 2 {
                throw LinkRelationParsingError.unexpectedSection(section)
            }
            
            let url = (section[0] as NSString).replacingOccurrences(ofRegex: "<(.*)>", with: "$1")
            let name = (section[1] as NSString).replacingOccurrences(ofRegex: "\\s+rel=\"(.*)\"", with: "$1")
            links[name!] = url
        }
        
        return links
    }

    /// The number of occurences of a given string found within the receiver.
    ///
    /// - Parameter aString: The string to search for.
    /// - Returns: The number of occurrences of `aString` found within the receiver. An empty string will result in a return value of `0`.
    public func count(of aString: String) -> Int {
        // (Modified from a solution here: https://stackoverflow.com/a/45073012)
        if aString.isEmpty {
            return 0
        }
        var count = 0
        var searchRange: Range<String.Index>?
        while let foundRange = range(of: aString, options: [], range: searchRange) {
            count += 1
            searchRange = Range(uncheckedBounds: (lower: foundRange.upperBound, upper: endIndex))
        }
        return count
    }
}
