//
//  MPManagedObject-CloudKit.swift
//  Feather
//
//  Created by Matias Piipari on 30/06/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation
import RegexKitLite

extension MPManagedObject {
    public class func recordZoneName() -> String {
        return (NSStringFromClass(self) as NSString).stringByReplacingOccurrencesOfRegex("^MP", withString: "")
    }
}
