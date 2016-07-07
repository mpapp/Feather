//
//  CloudKitStatus.swift
//  Feather
//
//  Created by Matias Piipari on 07/07/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation
import Freddy
import CloudKit

public struct CloudKitState: JSONEncodable, JSONDecodable {
    
    enum Error:ErrorType {
        case NoSavedState(MPDatabasePackageController)
    }
    
    private var recordZones:[CKRecordZoneID:String] = [CKRecordZoneID:String]()
    
    private let ownerID:CKRecordID
    
    public static func state(packageController: MPDatabasePackageController) throws -> CloudKitState {
        guard let stateURL = NSURL(fileURLWithPath: packageController.path).URLByAppendingPathComponent("cloudkit-state.json"),
              let statePath = stateURL.path where NSFileManager.defaultManager().fileExistsAtPath(statePath) else {
            throw Error.NoSavedState(packageController)
        }
        
        return try CloudKitState.init(json:try JSON(data: try NSData(contentsOfURL: stateURL, options:[])))
    }
    
    public func serverChangeToken(recordZoneID:CKRecordZoneID) -> String? {
        return self.recordZones[recordZoneID]
    }
    
    public init(json: JSON) throws {
        
        var state = [CKRecordZoneID:String]()
        
        self.ownerID = CKRecordID(recordName: try json.string("ownerName"))
        
        for item in try json.array("recordZones") {
            let zoneID = try CKRecordZoneID(zoneName: item.string("zoneName"), ownerName:item.string("ownerName"))
            let token = try item.string("serverChangeToken")
            state[zoneID] = token
        }
        
        self.recordZones = state
    }
    
    public func toJSON() -> JSON {
        return .Dictionary([
                "ownerName": .String(self.ownerID.recordName),
                "recordZones": .Array(self.recordZones.map { pair -> JSON in
                                .Dictionary([
                                    "zoneName":.String(pair.0.zoneName),
                                    "serverChangeToken":.String(pair.1)])
                })
            ])
    }
    
}
