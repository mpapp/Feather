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

public class CloudKitDatabasePackageListingService {
    
    public indirect enum Error:Swift.Error {
        case noPackageListSerializationURL
        case underlyingError(Swift.Error)
        case unexpectedNilResponseData
    }
    
    public typealias DatabasePackageMetadataListHandler = ([DatabasePackageMetadata]) -> Void
    
    fileprivate(set) public var packageList:CloudKitDatabasePackageList?
    fileprivate var databasePackageChangeToken:CKServerChangeToken?
    
    public let container:CKContainer
    public let database:CKDatabase
    fileprivate let operationQueue = OperationQueue()
    
    public init(container:CKContainer = CKContainer.default(), database:CKDatabase = CKContainer.default().privateCloudDatabase) {
        self.container = container
        self.database = database
        
        precondition(self.database == self.container.privateCloudDatabase || self.database == self.container.publicCloudDatabase, "Database should be the container's public or private database but is not.")
    }
    
    public static var packageMetadataZoneName:String {
        return "DatabasePackageMetadata"
    }
    
    public static func packageMetadataZoneID(_ ownerName:String) -> CKRecordZoneID {
        return CKRecordZoneID(zoneName: self.packageMetadataZoneName, ownerName: ownerName)
    }

    public func availableDatabasePackages(_ completionHandler:@escaping DatabasePackageMetadataListHandler,
                                                   errorHandler:@escaping CloudKitSyncService.ErrorHandler) {
        CloudKitSyncService.ensureUserAuthenticated(container, completionHandler: { ownerID in
            self._availableDatabasePackages(ownerID.recordName,
                                            completionHandler: completionHandler,
                                            errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    public func purgeAllRecordZones(_ completionHandler:@escaping (_ deletedZoneIDs:[CKRecordZoneID], _ errors:[Error]) -> Void) {
        CloudKitSyncService.ensureUserAuthenticated(container, completionHandler: { ownerID in
            let op = CKFetchRecordZonesOperation.fetchAllRecordZonesOperation()
            self.operationQueue.addOperation(op)
            
            op.fetchRecordZonesCompletionBlock = { zoneMap, error in
                if let error = error {
                    completionHandler([], [.underlyingError(error)])
                    return
                }
                
                guard let map = zoneMap else {
                    completionHandler([], [.unexpectedNilResponseData])
                    return
                }
                
                let zonesToDelete = Array(map.values.map({ $0.zoneID }))
                
                var allDeletedIDs = [CKRecordZoneID]()
                var allErrors = [Error]()
                
                let grp = DispatchGroup()
                for zoneChunk in zonesToDelete.chunks(withDistance: 10) {
                    grp.enter()
                    
                    let deleteOp = CKModifyRecordZonesOperation(recordZonesToSave: nil, recordZoneIDsToDelete: zoneChunk)
                    self.operationQueue.addOperation(deleteOp)
                    
                    deleteOp.modifyRecordZonesCompletionBlock = { _, deletedZoneIDs, error in
                        if let error = error {
                            allErrors.append(.underlyingError(error))
                            grp.leave()
                            return
                        }
                        
                        guard let deletedIDs = deletedZoneIDs else {
                            allErrors.append(Error.unexpectedNilResponseData)
                            grp.leave()
                            return
                        }
                        
                        allDeletedIDs.append(contentsOf: deletedIDs)
                        grp.leave()
                    }
                }
                
                grp.notify(queue: DispatchQueue.main) {
                    completionHandler(allDeletedIDs, allErrors)
                }
            }
        }) { error in
            completionHandler([], [.underlyingError(error)])
        }
    }
    
    fileprivate var packageListSerializationURL:URL? {
        guard let appSupportFolder = FileManager.default.applicationSupportFolder else {
            return nil
        }
        
        return URL(fileURLWithPath:((appSupportFolder as NSString).appendingPathComponent(Bundle.main.bundleIdentifier!) as NSString).appendingPathComponent("database-package-list-\(self.container.containerIdentifier!)-\(self.container.privateCloudDatabase === self.database ? "private" : "public").json"))
    }
    
    public func _availableDatabasePackages(_ ownerName:String,
                                           completionHandler:@escaping DatabasePackageMetadataListHandler,
                                           errorHandler:@escaping CloudKitSyncService.ErrorHandler) {
        
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
        
        func recordChanged(_ record:CKRecord) {
            let package = DatabasePackageMetadata(recordID: record.recordID, title: record["title"] as? String ?? nil, changeTag: record.recordChangeTag)
            
            // Replace if existing item found.
            // Maintaining sort order is not important.
            if let index = packages.index(where: { pkg in pkg.recordID == package.recordID }) {
                packages.remove(at: index)
            }
            packages.append(package)
        }
        
        func recordWithIDWasDeleted(_ record:CKRecordID) {
            if let index = packages.index(where: { $0.recordID.recordName == record.recordName }) {
                packages.remove(at: index)
            }
        }
        
        let op = CKFetchRecordChangesOperation(recordZoneID: CloudKitDatabasePackageListingService.packageMetadataZoneID(ownerName), previousServerChangeToken: databasePackageChangeToken)
        
        func fetchRecordChangesCompletion(_ serverChangeToken:CKServerChangeToken?,
                                          clientTokenData:Data?,
                                          error:Swift.Error?) {
            if let error = error {
                errorHandler(.underlyingError(error))
                return
            }
            
            if op.moreComing {
                let op = CKFetchRecordChangesOperation(recordZoneID: CloudKitDatabasePackageListingService.packageMetadataZoneID(ownerName), previousServerChangeToken: databasePackageChangeToken)
                op.previousServerChangeToken = serverChangeToken
                op.database = database
                op.recordChangedBlock = recordChanged
                op.recordWithIDWasDeletedBlock = recordWithIDWasDeleted
                op.fetchRecordChangesCompletionBlock = fetchRecordChangesCompletion
                
                OperationQueue.main.addOperation(op)
            }
            else {
                do {
                    guard let packageListSerializationURL = self.packageListSerializationURL else {
                        throw Error.noPackageListSerializationURL
                    }
                    
                    let packageList = CloudKitDatabasePackageList(packages: packages)
                    try packageList.serialize(toURL: packageListSerializationURL)
                    self.packageList = packageList
                }
                catch {
                    errorHandler(.underlyingError(error))
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
        
        OperationQueue.main.addOperation(op)
    }
    
}
