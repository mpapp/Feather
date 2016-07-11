//
//  CloudKitDatabasePackageListingService.swift
//  Feather
//
//  Created by Matias Piipari on 11/07/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation
import CloudKit
import FeatherExtensions

public struct CloudKitDatabasePackageListingService {
    
    public enum Error:ErrorType {
        case NoPackageListSerializationURL
        case UnderlyingError(ErrorType)
        case UnexpectedNilResponseData
    }
    
    public typealias DatabasePackageMetadataListHandler = ([DatabasePackageMetadata]) -> Void
    
    private(set) public var packageList:CloudKitDatabasePackageList?
    private var databasePackageChangeToken:CKServerChangeToken?
    
    public let container:CKContainer
    public let database:CKDatabase
    private let operationQueue = NSOperationQueue()
    
    public init(container:CKContainer = CKContainer.defaultContainer(), database:CKDatabase = CKContainer.defaultContainer().privateCloudDatabase) {
        self.container = container
        self.database = database
        
        precondition(self.database == self.container.privateCloudDatabase || self.database == self.container.publicCloudDatabase, "Database should be the container's public or private database but is not.")
    }
    
    public static var packageMetadataZoneName:String {
        return "DatabasePackageMetadata"
    }
    
    public static func packageMetadataZoneID(ownerName:String) -> CKRecordZoneID {
        return CKRecordZoneID(zoneName: self.packageMetadataZoneName, ownerName: ownerName)
    }

    public mutating func availableDatabasePackages(completionHandler:DatabasePackageMetadataListHandler, errorHandler:CloudKitSyncService.ErrorHandler) {
        CloudKitSyncService.ensureUserAuthenticated(container, completionHandler: { ownerID in
            self._availableDatabasePackages(ownerID.recordName, completionHandler: completionHandler, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    public func purgeAllRecordZones(completionHandler:(deletedZoneIDs:[CKRecordZoneID], errors:[Error]) -> Void) {
        CloudKitSyncService.ensureUserAuthenticated(container, completionHandler: { ownerID in
            let op = CKFetchRecordZonesOperation.fetchAllRecordZonesOperation()
            self.operationQueue.addOperation(op)
            
            op.fetchRecordZonesCompletionBlock = { zoneMap, error in
                if let error = error {
                    completionHandler(deletedZoneIDs: [], errors:[.UnderlyingError(error)])
                    return
                }
                
                guard let map = zoneMap else {
                    completionHandler(deletedZoneIDs: [], errors:[.UnexpectedNilResponseData])
                    return
                }
                
                let zonesToDelete = Array(map.values.map({ $0.zoneID }))
                
                var allDeletedIDs = [CKRecordZoneID]()
                var allErrors = [Error]()
                
                let grp = dispatch_group_create()
                for zoneChunk in zonesToDelete.chunks(withDistance: 10) {
                    dispatch_group_enter(grp)
                    
                    let deleteOp = CKModifyRecordZonesOperation(recordZonesToSave: nil, recordZoneIDsToDelete: zoneChunk)
                    self.operationQueue.addOperation(deleteOp)
                    
                    deleteOp.modifyRecordZonesCompletionBlock = { _, deletedZoneIDs, error in
                        if let error = error {
                            allErrors.append(.UnderlyingError(error))
                            dispatch_group_leave(grp)
                            return
                        }
                        
                        guard let deletedIDs = deletedZoneIDs else {
                            allErrors.append(Error.UnexpectedNilResponseData)
                            dispatch_group_leave(grp)
                            return
                        }
                        
                        allDeletedIDs.appendContentsOf(deletedIDs)
                        dispatch_group_leave(grp)
                    }
                }
                
                dispatch_group_notify(grp, dispatch_get_main_queue()) {
                    completionHandler(deletedZoneIDs: allDeletedIDs, errors: allErrors)
                }
            }
        }) { error in
            completionHandler(deletedZoneIDs:[], errors: [.UnderlyingError(error)])
        }
    }
    
    private var packageListSerializationURL:NSURL? {
        guard let appSupportFolder = NSFileManager.defaultManager().applicationSupportFolder else {
            return nil
        }
        
        return NSURL(fileURLWithPath:((appSupportFolder as NSString).stringByAppendingPathComponent(NSBundle.mainBundle().bundleIdentifier!) as NSString).stringByAppendingPathComponent("database-package-list-\(self.container.containerIdentifier!)-\(self.container.privateCloudDatabase === self.database ? "private" : "public").json"))
    }
    
    public mutating func _availableDatabasePackages(ownerName:String, completionHandler:DatabasePackageMetadataListHandler, errorHandler:CloudKitSyncService.ErrorHandler) {
        
        var packages:[DatabasePackageMetadata]
        
        if let pkgs = self.packageList?.packages {
            packages = pkgs
        }
        else if let serializationURL = self.packageListSerializationURL {
            do {
                let packageList = try CloudKitDatabasePackageList(contentsOfURL: serializationURL)
                self.packageList = packageList
                packages = packageList.packages
            }
            catch {
                packages = [DatabasePackageMetadata]()
           }
        }
        else {
            packages = [DatabasePackageMetadata]()
        }
        
        func recordChanged(record:CKRecord) {
            let package = DatabasePackageMetadata(recordID: record.recordID, title: record["title"] as? String ?? nil, changeTag: record.recordChangeTag)
            
            // Replace if existing item found.
            // Maintaining sort order is not important.
            if let index = packages.indexOf({ pkg in pkg.recordID == package.recordID }) {
                packages.removeAtIndex(index)
            }
            packages.append(package)
        }
        
        func recordWithIDWasDeleted(record:CKRecordID) {
            if let index = packages.indexOf({ $0.recordID.recordName == record.recordName }) {
                packages.removeAtIndex(index)
            }
        }
        
        let op = CKFetchRecordChangesOperation(recordZoneID: CloudKitDatabasePackageListingService.packageMetadataZoneID(ownerName), previousServerChangeToken: databasePackageChangeToken)
        
        func fetchRecordChangesCompletion(serverChangeToken:CKServerChangeToken?, clientTokenData:NSData?, error:NSError?) {
            if let error = error {
                errorHandler(.UnderlyingError(error))
                return
            }
            
            if op.moreComing {
                let op = CKFetchRecordChangesOperation(recordZoneID: CloudKitDatabasePackageListingService.packageMetadataZoneID(ownerName), previousServerChangeToken: databasePackageChangeToken)
                op.previousServerChangeToken = serverChangeToken
                op.database = database
                op.recordChangedBlock = recordChanged
                op.recordWithIDWasDeletedBlock = recordWithIDWasDeleted
                op.fetchRecordChangesCompletionBlock = fetchRecordChangesCompletion
                
                NSOperationQueue.mainQueue().addOperation(op)
            }
            else {
                do {
                    guard let packageListSerializationURL = self.packageListSerializationURL else {
                        throw Error.NoPackageListSerializationURL
                    }
                    
                    let packageList = CloudKitDatabasePackageList(packages: packages)
                    try packageList.serialize(toURL: packageListSerializationURL)
                    self.packageList = packageList
                }
                catch {
                    errorHandler(.UnderlyingError(error))
                    return
                }
                
                completionHandler(packages)
            }
        }
        
        op.previousServerChangeToken = databasePackageChangeToken
        op.database = database
        op.recordChangedBlock = recordChanged
        op.recordWithIDWasDeletedBlock = recordWithIDWasDeleted
        op.fetchRecordChangesCompletionBlock = fetchRecordChangesCompletion
        
        NSOperationQueue.mainQueue().addOperation(op)
    }
    
}
