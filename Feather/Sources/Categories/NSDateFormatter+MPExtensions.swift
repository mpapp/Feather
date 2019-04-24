//
//  NSDateFormatter+MPExtensions.swift
//  Feather
//
//  Created by Matias Piipari on 04/05/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

public extension DateFormatter {
    class func ISO8601Formatter() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.autoupdatingCurrent
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        
        return dateFormatter
    }
}
