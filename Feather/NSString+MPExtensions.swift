//
//  NSString+MPExtensions.swift
//  Feather
//
//  Created by Matias Piipari on 29/01/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

@objc public extension NSString {
    @objc public func XMLStringByRemovingDuplicateXMLDeclarations() -> String {
        // the preceding character is included in the pattern, therefore captured and included in output.
        // the pattern below matches to <?xml…?> that is not at the very beginning of the document.
        let regex = try! NSRegularExpression(pattern:"(.)<\\?xml.*\\?>", options:NSRegularExpression.Options.caseInsensitive)
        let modifiedString = regex.stringByReplacingMatches(in: self as String, options:[], range:NSRange(location: 0, length: self.length), withTemplate:"$1")
        
        return modifiedString
    }
    
    @objc public func isUUIDLike() -> Bool {
        return self.length == 36
            && self.substring(with: NSRange(location: 8,length: 1)) == "-"
            && self.substring(with: NSRange(location: 13,length: 1)) == "-"
            && self.substring(with: NSRange(location: 18,length: 1)) == "-"
            && self.substring(with: NSRange(location: 23,length: 1)) == "-"
    }
    
    @objc func hasOneOfPrefixes(_ prefixes: [String], caseInsensitive: Bool) -> Bool {
        for prefix in prefixes {
            if (self.hasPrefix(prefix)) {
                return true
            }
            else if caseInsensitive && self.lowercased.hasPrefix(prefix.lowercased()) {
                return true
            }
        }
        return false;
    }
}
