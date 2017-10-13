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
    
    /**
     
     Fix for a mind-boggling NSXMLDocument (and looking like also WebKit XMLSerializer) behaviour, which is:
     
     ```
     [[NSXMLDocument alloc] initWithXMLString:@"<html xmlns=\"http://www.w3.org/1999/xhtml\"><body><p>Hello world.</p></body></html>" options:MPDefaultXMLDocumentParsingOptions error:nil]);
     ```
     
     ...when again printed out as an XML string will yield:
     
     ```
     <?xml version="1.0" encoding="UTF-8" standalone="no"?><html xmlns="http://www.w3.org/1999/xhtml><body><p>Hello world.</p></body></html>
     ```
     
     ...meaning: the closing double quote for the XHTML namespace will just get dropped.
     */
    @objc func XMLStringByFixingPossiblyBrokenXMLNamespaces() -> String {
        var HTML = self.replacingOccurrences(of: "xmlns:m=\"http://schemas.openxmlformats.org/officeDocument/2006/math ", with: "xmlns:m=\"http://schemas.openxmlformats.org/officeDocument/2006/math\" ")
        HTML = HTML.replacingOccurrences(of: "xmlns:m=\"http://schemas.openxmlformats.org/officeDocument/2006/math>", with: "xmlns:m=\"http://schemas.openxmlformats.org/officeDocument/2006/math\">")
        HTML = HTML.replacingOccurrences(of: "xmlns:m=\"http://schemas.openxmlformats.org/officeDocument/2006/math/>", with: "xmlns:m=\"http://schemas.openxmlformats.org/officeDocument/2006/math\"/>")
        
        HTML = HTML.replacingOccurrences(of: "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main ", with: "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" ")
        HTML = HTML.replacingOccurrences(of: "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main>", with: "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">")
        HTML = HTML.replacingOccurrences(of: "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main/>", with: "xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"/>")

        HTML = HTML.replacingOccurrences(of: "xmlns:xlink=\"http://www.w3.org/1999/xlink ", with: "xmlns:xlink=\"http://www.w3.org/1999/xlink\" ")
        HTML = HTML.replacingOccurrences(of: "xmlns:xlink=\"http://www.w3.org/1999/xlink>", with: "xmlns:xlink=\"http://www.w3.org/1999/xlink\">")
        HTML = HTML.replacingOccurrences(of: "xmlns:xlink=\"http://www.w3.org/1999/xlink/>", with: "xmlns:xlink=\"http://www.w3.org/1999/xlink\"/>")

        HTML = HTML.replacingOccurrences(of:"xmlns=\"http://www.w3.org/2000/svg ", with: "xmlns=\"http://www.w3.org/2000/svg\" ")
        HTML = HTML.replacingOccurrences(of:"xmlns=\"http://www.w3.org/2000/svg>", with: "xmlns=\"http://www.w3.org/2000/svg\">")
        HTML = HTML.replacingOccurrences(of:"xmlns=\"http://www.w3.org/2000/svg/>", with: "xmlns=\"http://www.w3.org/2000/svg\"/>")

        HTML = HTML.replacingOccurrences(of: "xmlns=\"http://www.w3.org/1999/xhtml ", with: "xmlns=\"http://www.w3.org/1999/xhtml\" ")
        HTML = HTML.replacingOccurrences(of: "xmlns=\"http://www.w3.org/1999/xhtml>", with: "xmlns=\"http://www.w3.org/1999/xhtml\">")
        HTML = HTML.replacingOccurrences(of: "xmlns=\"http://www.w3.org/1999/xhtml/>", with: "xmlns=\"http://www.w3.org/1999/xhtml\"/>")

        return HTML;
    }
    
    @objc func XMLStringByRemovingXHTMLNamespace() -> String {
        return self.replacingOccurrences(of: "xmlns=\"http://www.w3.org/1999/xhtml\"", with: "")
    }
}
