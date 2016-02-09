//
//  NSString+MPExtensions.swift
//  Feather
//
//  Created by Matias Piipari on 29/01/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

public extension NSString {
    public func XMLStringByRemovingDuplicateXMLDeclarations() -> String {
        // the preceding character is included in the pattern, therefore captured and included in output.
        // the pattern below matches to <?xml…?> that is not at the very beginning of the document.
        let regex = try! NSRegularExpression(pattern:"(.)<\\?xml.*\\?>", options:NSRegularExpressionOptions.CaseInsensitive)
        let modifiedString = regex.stringByReplacingMatchesInString(self as String, options:[], range:NSRange(location: 0, length: self.length), withTemplate:"$1")
        
        return modifiedString
    }
    
    public func isUUIDLike() -> Bool {
        return self.length == 36
            && self.substringWithRange(NSRange(location: 8,length: 1)) == "-"
            && self.substringWithRange(NSRange(location: 13,length: 1)) == "-"
            && self.substringWithRange(NSRange(location: 18,length: 1)) == "-"
            && self.substringWithRange(NSRange(location: 23,length: 1)) == "-"
    }
}