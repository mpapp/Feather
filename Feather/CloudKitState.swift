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
    
    public init(contentsOfURL url:NSURL) throws {
        let data = try NSData(contentsOfURL: url, options: [])
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
    
    public func serialize(toURL url:NSURL) throws {
        let data = try self.toJSON().serialize()
        
        // ensure the containing directory exists.
        let containingDir = (url.path! as NSString).stringByDeletingLastPathComponent
        if !NSFileManager.defaultManager().fileExistsAtPath(containingDir) {
            try NSFileManager.defaultManager().createDirectoryAtURL(NSURL(fileURLWithPath:containingDir), withIntermediateDirectories: true, attributes: [:])
        }
        
        try data.writeToURL(url, options: [])
    }
}

public struct CloudKitState: JSONEncodable, JSONDecodable {
    
    enum Error:ErrorType {
        case NoSavedState(MPDatabasePackageController)
        case NoPackageController
    }
    
    private var recordZones:[CKRecordZoneID:CKServerChangeToken] = [CKRecordZoneID:CKServerChangeToken]()
    
    private let ownerName:String
    
    private(set) public weak var packageController:MPDatabasePackageController?
    
    public init(ownerName:String, packageController: MPDatabasePackageController) {
        self.ownerName = ownerName
        self.packageController = packageController
    }
    
    public func deserialize() throws -> CloudKitState {
        guard let packageController = self.packageController else {
            throw Error.NoPackageController
        }
        
        guard let stateURL = NSURL(fileURLWithPath: packageController.path).URLByAppendingPathComponent("cloudkit-state.json"),
            let statePath = stateURL.path where NSFileManager.defaultManager().fileExistsAtPath(statePath) else {
                throw Error.NoSavedState(packageController)
        }
        
        var state = try CloudKitState(json:try JSON(data: try NSData(contentsOfURL: stateURL, options:[])))
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
