//
//  MPManagedObject-CloudKit.swift
//  Feather
//
//  Created by Matias Piipari on 30/06/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation
import RegexKitLite
import CocoaLumberjackSwift

extension MPManagedObject {
    
    public class func recordType() -> String {
        return (NSStringFromClass(self) as NSString).replacingOccurrences(ofRegex: "^MP", with: "")
    }
    
    public class func recordZoneName() -> String {
        let equivalenceAnyClass:AnyClass = MPManagedObjectsController.equivalenceClass(forManagedObjectClass: self)

        guard let equivalenceClass = equivalenceAnyClass as? MPManagedObject.Type else {
            preconditionFailure("Equivalence class of \(type(of: self)) should be subclass of MPManagedObject: \(equivalenceAnyClass)")
        }
        
        // TODO: Find a more robust way to get rid of the NSKVONotifying_ prefix.
        let zoneName = (String(describing: equivalenceClass) as NSString).replacingOccurrences(ofRegex: "^MP", with: "").replacingOccurrences(of: "NSKVONotifying_", with: "")
        return zoneName
    }
}
