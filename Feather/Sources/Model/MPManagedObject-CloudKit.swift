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
        return (NSStringFromClass(self) as NSString).stringByReplacingOccurrencesOfRegex("^MP", withString: "")
    }
    
    public class func recordZoneName() -> String {
        let equivalenceAnyClass:AnyClass = MPManagedObjectsController.equivalenceClassForManagedObjectClass(self)

        guard let equivalenceClass = equivalenceAnyClass as? MPManagedObject.Type else {
            preconditionFailure("Equivalence class of \(self.dynamicType) should be subclass of MPManagedObject: \(equivalenceAnyClass)")
        }
        
        let zoneName = (String(equivalenceClass) as NSString).stringByReplacingOccurrencesOfRegex("^MP", withString: "")
        return zoneName
    }
}
