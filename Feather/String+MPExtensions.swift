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
    func matches(regex: String, caseSensitively: Bool = false) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: caseSensitively ? [] : [.caseInsensitive]) else { return [] }
        let matches  = regex.matches(in: self, options: [], range: NSMakeRange(0, self.count))
        return matches.map { match in
            return String(self[Range(match.range, in: self)!])
        }
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
}
