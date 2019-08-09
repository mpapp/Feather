//
//  String+Extensions.swift
//  Feather
//
//  Created by Matias Piipari on 18/05/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

public extension String {
    func stringAroundOccurrence(ofString str:String, maxPadding:UInt, options:NSString.CompareOptions = []) -> String? {
        guard let range = self.range(of: str, options:options, range: nil, locale: nil) else {
            return nil
        }

        let p = Int(maxPadding)
        let r = (self.index(range.lowerBound, offsetBy: -p, limitedBy: self.startIndex) ?? self.startIndex)
                ..<
                (self.index(range.upperBound, offsetBy: p, limitedBy: self.endIndex) ?? self.endIndex)
        
        return String(self[r])
    }
    
    enum LinkRelationParsingError: Error {
        case emptyString
        case unexpectedSection([String])
    }
    
    func linkRelations() throws -> [String:String] {
        if self.isEmpty {
            throw LinkRelationParsingError.emptyString
        }
        
        var links = [String:String]()
        for part in self.components(separatedBy: ",") {
            let section = part.components(separatedBy: ";")
            
            if section.count != 2 {
                throw LinkRelationParsingError.unexpectedSection(section)
            }

            let urlStr = section[0]
            let urlPattern = try NSRegularExpression(pattern: "<(.*)>", options: [])
            let url = urlPattern.stringByReplacingMatches(in: urlStr, options: NSRegularExpression.MatchingOptions(),
                                                          range: NSMakeRange(0, urlStr.count), withTemplate: "$1")
            
            let nameStr = section[1]
            let namePattern = try NSRegularExpression(pattern: "\\s+rel=\"(.*)\"", options: [])
            let name = namePattern.stringByReplacingMatches(in: nameStr, options: NSRegularExpression.MatchingOptions(),
                                                            range: NSMakeRange(0, nameStr.count),
                                                            withTemplate: "$1")
            links[name] = url
        }
        
        return links
    }

    /// The number of occurences of a given string found within the receiver.
    ///
    /// - Parameter aString: The string to search for.
    /// - Returns: The number of occurrences of `aString` found within the receiver. An empty string will result in a return value of `0`.
    func count(occurrencesOf aString: String) -> Int {
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
