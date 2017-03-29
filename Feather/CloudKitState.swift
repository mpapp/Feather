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
        self.packages = try json.array("packages").map { package -> DatabasePackageMetadata in
            let packageMetadataZoneID = CKRecordZoneID(zoneName: try package.string("zoneName"), ownerName: try package.string("ownerName"))
            let recordID = CKRecordID(recordName: try package.string("recordName"), zoneID: packageMetadataZoneID)
            
            var title:String? = try package.string("title", alongPath: [.MissingKeyBecomesNil])
            if title == "" {
                title = nil
            }
            
            var changeTag:String? = try package.string("changeTag", alongPath: [.MissingKeyBecomesNil])
            if changeTag == "" {
                changeTag = nil
            }
            
            return DatabasePackageMetadata(recordID: recordID, title: title, changeTag: changeTag)
        }
    }
    
    public func toJSON() -> JSON {
        return .Array(self.packages.map { package -> JSON in
             [ "recordName":.String(package.recordID.recordName),
                    "title":.String(package.title ?? ""),
                 "zoneName":.String(package.recordID.zoneID.zoneName),
                "ownerName":.String(package.recordID.zoneID.ownerName),
                "changeTag":.String(package.changeTag ?? "")] })
    }
    
    public func serialize(toURL url:URL) throws {
        let data = try self.toJSON().serialize()
        
        // ensure the containing directory exists.
        let containingDir = (url.path as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: containingDir) {
            try FileManager.default.createDirectory(at: URL(fileURLWithPath:containingDir), withIntermediateDirectories: true, attributes: [:])
        }
        
        try data.writeToURL(url, options: [])
    }
}

public struct CloudKitState: JSONEncodable, JSONDecodable {
    
    enum Error:Error {
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
        
        guard let stateURL = URL(fileURLWithPath: packageController.path).appendingPathComponent("cloudkit-state.json"),
            let statePath = stateURL.path, FileManager.default.fileExists(atPath: statePath) else {
                throw Error.noSavedState(packageController)
        }
        
        var state = try CloudKitState(json:try JSON(data: try Data(contentsOfURL: stateURL, options:[])))
        state.packageController = packageController
        
        return state
    }
    
    public func serialize() throws {
        guard let packageController = self.packageController else {
            throw Error.noPackageController
        }
        
        guard let url = URL(fileURLWithPath: packageController.path).appendingPathComponent("cloudkit-state.json") else {
            preconditionFailure("File URL \(packageController.path) can't be appended to to create a file URL.")
        }
        
        let serializedData = try self.toJSON().serialize()
        try serializedData.writeToURL(url, options: [])
    }
    
    public func serverChangeToken(forZoneID recordZoneID:CKRecordZoneID) -> CKServerChangeToken? {
        return self.recordZones[recordZoneID]
    }
    
    public mutating func setServerChangeToken(_ token:CKServerChangeToken, forZoneID recordZoneID:CKRecordZoneID) {
        self.recordZones[recordZoneID] = token
    }
    
    public init(json: JSON) throws {
        self.ownerName = try json.string("ownerName")
        
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
                "ownerName": .String(self.ownerName),
                "recordZones": .Array(self.recordZones.map { pair -> JSON in
                    let tokenStr = NSKeyedArchiver.archivedDataWithRootObject(pair.1).base64EncodedStringWithOptions([])
                    return .Dictionary(["zoneName":.String(pair.0.zoneName), "serverChangeToken":.String(tokenStr)])
                })
            ])
    }
    
}
