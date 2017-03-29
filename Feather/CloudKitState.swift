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

public struct DatabasePackageMetadata {
    let recordID:CKRecordID
    let title:String?
    let changeTag:String?
}

public struct CloudKitDatabasePackageList: JSONEncodable, JSONDecodable {
    public let packages:[DatabasePackageMetadata]
    
    public init(contentsOfURL url:URL) throws {
        let data = try Data(contentsOf: url, options: [])
        try self.init(json: try JSON(data:data))
    }
    
    public init(packages:[DatabasePackageMetadata]) {
        self.packages = packages
    }
    
    public init(json: JSON) throws {
        self.packages = try json.getArray(at: "packages").map { package -> DatabasePackageMetadata in
            let packageMetadataZoneID = CKRecordZoneID(zoneName: try package.getString(at: "zoneName"),
                                                       ownerName: try package.getString(at: "ownerName"))
            let recordID = CKRecordID(recordName: try package.getString(at: "recordName"), zoneID: packageMetadataZoneID)
            
            var title:String? = try package.getString(at: "title", alongPath: [.missingKeyBecomesNil])
            if title == "" {
                title = nil
            }
            
            var changeTag:String? = try package.getString(at: "changeTag", alongPath: [.missingKeyBecomesNil])
            if changeTag == "" {
                changeTag = nil
            }
            
            return DatabasePackageMetadata(recordID: recordID, title: title, changeTag: changeTag)
        }
    }
    
    public func toJSON() -> JSON {
        return .array(self.packages.map { package -> JSON in
             [ "recordName":.string(package.recordID.recordName),
                    "title":.string(package.title ?? ""),
                 "zoneName":.string(package.recordID.zoneID.zoneName),
                "ownerName":.string(package.recordID.zoneID.ownerName),
                "changeTag":.string(package.changeTag ?? "")] })
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

public struct CloudKitState: JSONEncodable, JSONDecodable {
    
    enum Error:Swift.Error {
        case noSavedState(MPDatabasePackageController)
        case noPackageController
    }
    
    fileprivate var recordZones:[CKRecordZoneID:CKServerChangeToken] = [CKRecordZoneID:CKServerChangeToken]()
    
    fileprivate let ownerName:String
    
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
