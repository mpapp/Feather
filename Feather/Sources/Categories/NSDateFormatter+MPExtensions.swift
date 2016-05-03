//
//  NSDateFormatter+MPExtensions.swift
//  Feather
//
//  Created by Matias Piipari on 04/05/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

public extension NSDateFormatter {
    public class func ISO8601Formatter() -> NSDateFormatter {
        let dateFormatter = NSDateFormatter()
        dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        dateFormatter.timeZone = NSTimeZone.localTimeZone()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        
        return dateFormatter
    }
}