//
//  String+MPExtensions.swift
//  FeatherExtensions
//
//  Created by Matias Piipari on 11/07/2019.
//  Copyright © 2019 Matias Piipari. All rights reserved.
//

import Foundation

fileprivate let badChars = CharacterSet.alphanumerics.inverted

public extension String {
    func matches(regex: String, caseSensitively: Bool) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: caseSensitively ? [] : [.caseInsensitive]) else { return [] }
        let matches  = regex.matches(in: self, options: [], range: NSMakeRange(0, self.count))
        return matches.map { match in
            return String(self[Range(match.range, in: self)!])
        }
    }

    func stringByReplacingOccurrences(ofRegex pattern: String, withTemplate replacement: String, caseSensitively: Bool) throws -> String {
        let pattern = try NSRegularExpression(pattern: pattern, options: caseSensitively ? [] : .caseInsensitive)
        return pattern.stringByReplacingMatches(in: self, options: [],
                                                range: NSMakeRange(0, self.count), withTemplate: replacement)
    }

    func isMatched(byRegex pattern: String, caseSensitively: Bool = false) -> Bool {
        return self.matches(regex: pattern, caseSensitively: caseSensitively).count > 0
    }
    
    var uppercasingFirst: String {
        return prefix(1).uppercased() + dropFirst()
    }
    
    var lowercasingFirst: String {
        return prefix(1).lowercased() + dropFirst()
    }

    var camelCased: String {
        guard !isEmpty else {
            return ""
        }
        
        let parts = self.components(separatedBy: badChars)
        
        let first = String(describing: parts.first!).lowercasingFirst
        let rest = parts.dropFirst().map({String($0).uppercasingFirst})
        
        return ([first] + rest).joined(separator: "")
    }

    var sentenceCased: String {
        return prefix(1).capitalized + dropFirst()
    }
    
    func capturedGroups(withRegex pattern: String, caseSensitively: Bool) -> [String] {
        var results = [String]()
        
        var regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: caseSensitively ? [] : .caseInsensitive)
        } catch {
            return results
        }
        let matches = regex.matches(in: self, options: [], range: NSRange(location:0, length: self.count))
        
        guard let match = matches.first else { return results }
        
        let lastRangeIndex = match.numberOfRanges - 1
        guard lastRangeIndex >= 1 else { return results }
        
        for i in 1...lastRangeIndex {
            let capturedGroupIndex = match.range(at: i)
            let matchedString = (self as NSString).substring(with: capturedGroupIndex)
            results.append(matchedString)
        }
        
        return results
    }
}
