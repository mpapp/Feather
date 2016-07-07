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
import FeatherExtensions

public struct CloudKitState: JSONEncodable, JSONDecodable {
    
    enum Error:ErrorType {
        case NoSavedState(MPDatabasePackageController)
        case NoPackageController
    }
    
    private var recordZones:[CKRecordZoneID:CKServerChangeToken] = [CKRecordZoneID:CKServerChangeToken]()
    
    private let ownerID:CKRecordID
    
    private weak var packageController:MPDatabasePackageController?
    
    public static func state(packageController packageController: MPDatabasePackageController) throws -> CloudKitState {
        guard let stateURL = NSURL(fileURLWithPath: packageController.path).URLByAppendingPathComponent("cloudkit-state.json"),
              let statePath = stateURL.path where NSFileManager.defaultManager().fileExistsAtPath(statePath) else {
            throw Error.NoSavedState(packageController)
        }
        
        var state = try CloudKitState.init(json:try JSON(data: try NSData(contentsOfURL: stateURL, options:[])))
        state.packageController = packageController
        
        return state
    }
    
    public func serialize() throws {
        guard let packageController = self.packageController else {
            throw Error.NoPackageController
        }
        
        guard let url = NSURL(fileURLWithPath: packageController.path).URLByAppendingPathComponent("cloudkit-state.json") else {
            preconditionFailure("File URL \(packageController.path) can't be appended to to create a file URL.")
        }
        
        let serializedData = try self.toJSON().serialize()
        try serializedData.writeToURL(url, options: [])
    }
    
    public func serverChangeToken(forZoneID recordZoneID:CKRecordZoneID) -> CKServerChangeToken? {
        return self.recordZones[recordZoneID]
    }
    
    public mutating func setServerChangeToken(token:CKServerChangeToken, forZoneID recordZoneID:CKRecordZoneID) {
        self.recordZones[recordZoneID] = token
    }
    
    public init(json: JSON) throws {
        self.ownerID = CKRecordID(recordName: try json.string("ownerName"))
        
        let items = try json.array("recordZones").flatMap { item -> (CKRecordZoneID, CKServerChangeToken)? in
            let zoneID = try CKRecordZoneID(zoneName: item.string("zoneName"), ownerName:item.string("ownerName"))
            
            let tokenStr = try item.string("serverChangeToken")
            
            guard let data = NSData(base64EncodedString: tokenStr, options: []) else {
                return nil
            }
            
            guard let token = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? CKServerChangeToken else {
                return nil
            }
            
            return (zoneID, token)
        }
        
        self.recordZones = [CKRecordZoneID:CKServerChangeToken](withPairs:items)
    }
    
    public func toJSON() -> JSON {
        return .Dictionary([
                "ownerName": .String(self.ownerID.recordName),
                "recordZones": .Array(self.recordZones.map { pair -> JSON in
                    let tokenStr = NSKeyedArchiver.archivedDataWithRootObject(pair.1).base64EncodedStringWithOptions([])
                    return .Dictionary(["zoneName":.String(pair.0.zoneName), "serverChangeToken":.String(tokenStr)])
                })
            ])
    }
    
}
