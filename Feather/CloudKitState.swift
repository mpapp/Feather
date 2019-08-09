//
//  CloudKitStatus.swift
//  Feather
//
//  Created by Matias Piipari on 07/07/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation
import CloudKit
import FeatherExtensions

public struct DatabasePackageMetadata: Codable {
    let title:String?
    let changeTag:String?
    private let zoneName: String
    private let ownerName: String
    private let recordName: String

    enum CodingKeys: String, CodingKey, CaseEnumerable {
        case title
        case changeTag
        case zoneName
        case ownerName
        case recordName
    }

    lazy let zoneID: CKRecordZoneID  = {
        return CKRecordZoneID(zoneName: try package.getString(at: "zoneName"),
                               ownerName: try package.getString(at: "ownerName"))
    }

    lazy let recordID: CKRecordID = {
        return CKRecordID(recordName: recordName, zoneID: zoneID)
    }
}

public struct CloudKitDatabasePackageList: Codable {
    public let packages:[DatabasePackageMetadata]
    
    public init(contentsOfURL url:URL) throws {
        let data = try Data(contentsOf: url, options: [])
        try self.init(json: try JSON(data:data))
    }
    
    public init(packages:[DatabasePackageMetadata]) {
        self.packages = packages
    }
    
    public func serialize(toURL url:URL) throws {
        let data = try self.toJSON().serialize()
        
        // ensure the containing directory exists.
        let containingDir = (url.path as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: containingDir) {
            try FileManager.default.createDirectory(at: URL(fileURLWithPath:containingDir), withIntermediateDirectories: true, attributes: [:])
        }
        
        try data.write(to: url, options: [])
    }
}

public struct CloudKitState: Codable {
    
    enum Error: Swift.Error {
        case noSavedState(MPDatabasePackageController)
        case noPackageController
    }
    
    private var recordZones:[CKRecordZoneID: CKServerChangeToken] = [CKRecordZoneID:CKServerChangeToken]()
    private let ownerName:String
    
    fileprivate(set) public weak var packageController:MPDatabasePackageController?
    
    public init(ownerName:String, packageController: MPDatabasePackageController) {
        self.ownerName = ownerName
        self.packageController = packageController
    }
    
    public func deserialize() throws -> CloudKitState {
        guard let packageController = self.packageController else {
            throw Error.noPackageController
        }
        
        let stateURL = URL(fileURLWithPath: packageController.path).appendingPathComponent("cloudkit-state.json")
        let statePath = stateURL.path
        
        guard FileManager.default.fileExists(atPath: statePath) else {
                throw Error.noSavedState(packageController)
        }

        var state = try CloudKitState(json:try JSON(data: try Data(contentsOf: stateURL, options:[])))
        state.packageController = packageController
        
        return state
    }
    
    public func serialize() throws {
        guard let packageController = self.packageController else {
            throw Error.noPackageController
        }
        
        let url = URL(fileURLWithPath: packageController.path).appendingPathComponent("cloudkit-state.json")
        
        let serializedData = try self.toJSON().serialize()
        try serializedData.write(to: url, options: [])
    }
    
    public func serverChangeToken(forZoneID recordZoneID:CKRecordZoneID) -> CKServerChangeToken? {
        return self.recordZones[recordZoneID]
    }
    
    public mutating func setServerChangeToken(_ token:CKServerChangeToken, forZoneID recordZoneID:CKRecordZoneID) {
        self.recordZones[recordZoneID] = token
    }
    
    public init(json: JSON) throws {
        self.ownerName = try json.getString(at: "ownerName")
        
        let items = try json.getArray(at: "recordZones").flatMap { item -> (CKRecordZoneID, CKServerChangeToken)? in
            let zoneID = try CKRecordZoneID(zoneName: item.getString(at: "zoneName"),
                                            ownerName: item.getString(at: "ownerName"))
            
            let tokenStr = try item.getString(at: "serverChangeToken")
            
            guard let data = Data(base64Encoded: tokenStr, options: []) else {
                return nil
            }
            
            guard let token = NSKeyedUnarchiver.unarchiveObject(with: data) as? CKServerChangeToken else {
                return nil
            }
            
            return (zoneID, token)
        }
        
        self.recordZones = [CKRecordZoneID:CKServerChangeToken](withPairs:items)
    }
    
    public func toJSON() -> JSON {
        return .dictionary([
                "ownerName": .string(self.ownerName),
                "recordZones": .array(self.recordZones.map { pair -> JSON in
                    let tokenStr = NSKeyedArchiver.archivedData(withRootObject: pair.1)
                                        .base64EncodedString()
                    return .dictionary(["zoneName": .string(pair.0.zoneName),
                                        "serverChangeToken": .string(tokenStr)])
                })
            ])
    }
    
}
