//
//  CloudKitSyncService.swift
//  Manuscripts
//
//  Created by Matias Piipari on 19/06/2016.
//  Copyright © 2016 Manuscripts.app Limited. All rights reserved.
//

import Foundation
import CloudKit
import RegexKitLite
import MPRateLimiter
import CocoaLumberjackSwift
import FeatherExtensions

@objc public class CloudKitSyncService: NSObject {
    
    public enum Error: ErrorType {
        case NilPackageController
        case OwnerUnknown
        case PartialError(CKErrorCode)
        case NoRecordToDeleteWithID(CKRecordID)
        case UnderlyingError(ErrorType)
        case MissingServerChangeToken(CKRecordZone)
        case StateInitializationFailed
        case UnexpectedRecords([CKRecord]?)
    }
    
    weak var packageController:MPDatabasePackageController?
    let container:CKContainer
    let database:CKDatabase
    public let recordZoneRepository:CloudKitRecordZoneRepository
    
    var state:CloudKitState?
    
    public var ownerID:CKRecordID?
    public var ignoredKeys:[String]
    
    private let operationQueue:NSOperationQueue = NSOperationQueue()
    
    public init(packageController:MPDatabasePackageController, container:CKContainer? = CKContainer.defaultContainer(), database:CKDatabase? = CKContainer.defaultContainer().privateCloudDatabase, ignoredKeys:[String]) throws {
        self.packageController = packageController
        self.container = container ?? CKContainer.defaultContainer()
        self.database = database ?? CKContainer.defaultContainer().privateCloudDatabase
        self.recordZoneRepository = CloudKitRecordZoneRepository(zoneSuffix: packageController.identifier)
        self.ignoredKeys = ignoredKeys
        self.operationQueue.maxConcurrentOperationCount = 1
        
        super.init()
        
        precondition(self.database == self.container.privateCloudDatabase || self.database == self.container.publicCloudDatabase, "Database should be the container's public or private database but is not.")
        
        if #available(OSX 10.11, *) {
            NSNotificationCenter.defaultCenter().addObserverForName(CKAccountChangedNotification, object: nil, queue: NSOperationQueue.mainQueue()) { notification in
                DDLogInfo("Account changed: \(notification)")
            }
        }
    }
    
    private func allRecords() throws -> [CKRecord] {
        guard let packageController = self.packageController else {
            throw Error.NilPackageController
        }
        
        guard let ownerName = self.ownerID?.recordName else {
            throw Error.OwnerUnknown
        }

        let serializer = CloudKitSerializer(ownerName:ownerName, recordZoneRepository: self.recordZoneRepository, ignoredKeys: self.ignoredKeys)
        
        // TODO: support serialising also MPMetadata objects.
        let records = try packageController.allObjects.filter({ o -> Bool in
            return o is MPManagedObject
            }).map { o -> CKRecord in
                guard let mo = o as? MPManagedObject else {
                    preconditionFailure("Expecting MPManagedObject instances to come through.")
                }
                let record = try serializer.serialize(mo)
                return record
            }
        
        return records
    }
    
    public typealias UserAuthenticationCompletionHandler = (ownerID:CKRecordID)->Void
    public func ensureUserAuthenticated(completionHandler:UserAuthenticationCompletionHandler, errorHandler:ErrorHandler) {
        if let ownerID = self.ownerID {
            completionHandler(ownerID:ownerID)
            return
        }
        self.container.fetchUserRecordIDWithCompletionHandler() { recordID, error in
            if let error = error {
                errorHandler(Error.UnderlyingError(error))
                return
            }
            else if let recordID = recordID {
                self.ownerID = recordID
                completionHandler(ownerID:recordID)
                return
            }
            else {
                preconditionFailure("Both error and record were nil?")
            }
        }
    }
 
    public var recordZoneNames:[String] {
        let zoneNames = MPManagedObject.subclasses().flatMap { cls -> String? in
            let moClass = cls as! MPManagedObject.Type
            if String(moClass).containsString("Mixin") {
                return nil
            }
            
            if self.packageController!.controllerForManagedObjectClass(moClass) == nil {
                return nil
            }
            
            return (MPManagedObjectsController.equivalenceClassForManagedObjectClass(moClass) as! MPManagedObject.Type).recordZoneName()
        }
        
        return NSOrderedSet(array: zoneNames + [self.packageMetadataZoneName]).array as! [String]
    }
    
    public func recordZones(ownerName:String) throws -> [CKRecordZone] {
        let zones = try MPManagedObject.subclasses().flatMap { cls -> CKRecordZone? in
            let moClass = cls as! MPManagedObject.Type
            if String(moClass).containsString("Mixin") {
                return nil
            }
            
            guard let _ = self.packageController!.controllerForManagedObjectClass(moClass) else {
                return nil
            }
            
            let zone = try self.recordZoneRepository.recordZone(objectType: moClass, ownerName: ownerName)
            return zone
        }
        
        let packageMetadataZone = CKRecordZone(zoneID: self.packageMetadataZoneID(ownerName: ownerName))
        return NSOrderedSet(array: zones + [packageMetadataZone]).array as! [CKRecordZone]
    }
    
    private var recordZonesChecked:[CKRecordZone]? = nil // Record zones created by the app won't change during app runtime. You may as well just check them once.
    
    public func ensureRecordZonesExist(completionHandler:(ownerID:CKRecordID, recordZones:[CKRecordZone])->Void, errorHandler:ErrorHandler) {
        self.ensureUserAuthenticated({ ownerID in
            if let recordZonesChecked = self.recordZonesChecked {
                completionHandler(ownerID: ownerID, recordZones: recordZonesChecked)
                return
            }
            
            self._ensureRecordZonesExist(ownerID.recordName, completionHandler:{ recordZones in
                self.recordZonesChecked = recordZones
                completionHandler(ownerID:ownerID, recordZones: recordZones)
            }, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    private func _ensureRecordZonesExist(ownerName:String, completionHandler:(recordZones:[CKRecordZone])->Void, errorHandler:ErrorHandler) {
        let op:CKModifyRecordZonesOperation
        do {
            op = CKModifyRecordZonesOperation(recordZonesToSave: try self.recordZones(ownerName), recordZoneIDsToDelete: [])
            op.database = self.database
        }
        catch {
            errorHandler(.UnderlyingError(error))
            return
        }
        
        self.operationQueue.addOperation(op)
        
        op.modifyRecordZonesCompletionBlock = { savedRecordZones, deletedRecordZones, error in
            if let error = error {
                errorHandler(.UnderlyingError(error))
                return
            }
            
            guard let recordZones = savedRecordZones else {
                preconditionFailure("Unexpectedly no saved record zones although no error occurred.")
            }
            
            completionHandler(recordZones:recordZones)
        }
    }
    
    public typealias ErrorHandler = (CloudKitSyncService.Error)->Void
    public typealias SubscriptionCompletionHandler = (savedSubscriptions:[CKSubscription], failedSubscriptions:[(subscription:CKSubscription, error:ErrorType)]?, errorHandler:ErrorType?) -> Void
    
    public func ensureSubscriptionsExist(completionHandler:SubscriptionCompletionHandler) {
        self.ensureRecordZonesExist({ ownerID, _ in
            self._ensureSubscriptionsExist(ownerID.recordName, completionHandler: completionHandler)
        }) { err in
            completionHandler(savedSubscriptions: [], failedSubscriptions: nil, errorHandler: err)
        }
    }
    
    private func _ensureSubscriptionsExist(ownerName:String, completionHandler:SubscriptionCompletionHandler) {
        let subscriptions = self.recordZoneNames.map { zoneName -> CKSubscription in
            let zoneID = CKRecordZoneID(zoneName: zoneName, ownerName: ownerName)
            return CKSubscription(zoneID: zoneID, subscriptionID: "\(zoneName)-subscription", options: [])
        }
        
        let save = CKModifySubscriptionsOperation(subscriptionsToSave: subscriptions, subscriptionIDsToDelete: [])
        save.database = self.database
        self.operationQueue.addOperation(save)
        
        save.modifySubscriptionsCompletionBlock = { savedSubscriptions, deletedSubscriptions, error in
            if let error = error {
                print(error)
                completionHandler(savedSubscriptions: savedSubscriptions ?? [], failedSubscriptions: nil, errorHandler: error)
            }
            else {
                completionHandler(savedSubscriptions: savedSubscriptions ?? [], failedSubscriptions: nil, errorHandler: nil)
            }
        }
    }
    
    public typealias PushCompletionHandler = (savedRecords:[CKRecord], saveFailures:[(record:CKRecord, error:ErrorType)]?, deletedRecordIDs:[CKRecordID], deletionFailures:[(recordID:CKRecordID, error:ErrorType)]?, errorHandler:ErrorType?)->Void
    
    public func push(completionHandler:PushCompletionHandler, errorHandler:ErrorHandler) {
        self.ensureUserAuthenticated({ ownerID in
            self._ensureRecordZonesExist(ownerID.recordName, completionHandler: { recordZones in
                self._push(completionHandler, errorHandler: errorHandler)
            }, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    private func _push(completionHandler:PushCompletionHandler, errorHandler:ErrorHandler) {
        var recordsMap = [CKRecordID:CKRecord]()
        let records:[CKRecord]
        do {
            records = try self.allRecords()
            for record in records { recordsMap[record.recordID] = record }
        }
        catch {
            completionHandler(savedRecords:[], saveFailures:nil, deletedRecordIDs:[], deletionFailures:nil, errorHandler:error)
            return
        }
        
        let save = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: [])
        save.savePolicy = CKRecordSavePolicy.AllKeys
        save.database = self.database
        
        self.operationQueue.addOperation(save)
        
        // This block reports an error of type partialFailure when it saves or deletes only some of the records successfully. The userInfo dictionary of the error contains a CKPartialErrorsByItemIDKey key whose value is an NSDictionary object. The keys of that dictionary are the IDs of the records that were not saved or deleted, and the corresponding values are error objects containing information about what happened.
        save.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            guard let err = error else {
                completionHandler(savedRecords: savedRecords ?? [], saveFailures: nil, deletedRecordIDs: deletedRecordIDs ?? [], deletionFailures: nil, errorHandler: nil)
                return
            }
            
            print("Error: \(err), \(err.userInfo), \(err.userInfo[CKPartialErrorsByItemIDKey]), \(err.userInfo[CKPartialErrorsByItemIDKey]!.dynamicType)")
            if let partialErrorInfo = err.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecordID:NSError] {
                
                print("Partial error info: \(partialErrorInfo)")
                
                let failedSaves = partialErrorInfo.flatMap { (recordID, errorInfo) -> (record:CKRecord, error:ErrorType)? in
                    // TODO: filter by error type
                    if let record = recordsMap[recordID] {
                        return (record:record, error:Error.UnderlyingError(errorInfo))
                    }
                    return nil
                }
                
                // TODO: handle partial failures by retrying them in case the issue is due to something recoverable.
                completionHandler(savedRecords: savedRecords ?? [], saveFailures:failedSaves, deletedRecordIDs: deletedRecordIDs ?? [], deletionFailures:nil, errorHandler: nil)
            }
            else {
                completionHandler(savedRecords: savedRecords ?? [], saveFailures:nil, deletedRecordIDs: deletedRecordIDs ?? [], deletionFailures: nil, errorHandler: err)
            }
        }
    }
    
    public typealias PullCompletionHandler = (failedChanges:[(record:CKRecord, error:Error)]?, failedDeletions:[(recordID:CKRecordID, error:Error)]?)->Void
    
    public func pull(completionHandler:([Error])->Void) {
        let grp = dispatch_group_create()
        
        dispatch_group_enter(grp) // 1 enter
        
        let errorQ = dispatch_queue_create("push-error-queue", nil)
        
        var errors = [Error]()
        
        self.ensureRecordZonesExist({ ownerID, recordZones in
            let recordZoneNames = recordZones.map { $0.zoneID.zoneName }
            
            DDLogDebug("Pulling from record zones: \(recordZoneNames)")
            for recordZone in recordZones {
                dispatch_group_enter(grp) // 2 enter
                self.pull(recordZone, completionHandler: { failedChanges, failedDeletions in
                    for failedChange in failedChanges ?? [] {
                        dispatch_sync(errorQ) {
                            errors.append(failedChange.error)
                        }
                    }
                
                    for failedDeletion in failedDeletions ?? [] {
                        dispatch_sync(errorQ) {
                            errors.append(failedDeletion.error)
                        }
                    }
                    
                    dispatch_group_leave(grp) // 2A leave
                    }, errorHandler: { error in
                        dispatch_sync(errorQ) {
                            errors.append(error)
                        }
                        dispatch_group_leave(grp) // 2B leave
                })
            }
            
            dispatch_group_leave(grp) // 1A leave

        }) { error in
            dispatch_sync(errorQ) {
                errors.append(.UnderlyingError(error))
            }
            dispatch_group_leave(grp) // 1B leave
            return
        }
        
        dispatch_group_notify(grp, dispatch_get_main_queue()) { 
            completionHandler(errors)
        }
    }
    
    public func pull(recordZone:CKRecordZone, completionHandler:PullCompletionHandler, errorHandler:ErrorHandler) {
        self.ensureRecordZonesExist({ ownerID, _ in
            self._pull(ownerID.recordName, recordZone: recordZone, completionHandler: completionHandler, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    public func _pull(ownerName:String, recordZone:CKRecordZone, completionHandler:PullCompletionHandler, errorHandler:ErrorHandler) {
        let fetchRecords = CKFetchRecordsOperation()
        fetchRecords.database = self.database
        
        guard let packageController = self.packageController else {
            errorHandler(.NilPackageController)
            return
        }
        
        let deserializer = CloudKitDeserializer(packageController: packageController)
        
        self.operationQueue.addOperation(fetchRecords)
        
        if self.state == nil {
            let state = CloudKitState(ownerName: ownerName, packageController: packageController, packages: [])
            do {
                self.state = try state.deserialize()
            }
            catch {
                self.state = state
            }
        }
        
        guard var state = self.state else {
            errorHandler(.StateInitializationFailed)
            return
        }
        
        let prevChangeToken = self.state?.serverChangeToken(forZoneID: recordZone.zoneID)
        let op = CKFetchRecordChangesOperation(recordZoneID: recordZone.zoneID, previousServerChangeToken:prevChangeToken)
        op.database = self.database
        
        var changeFails = [(record:CKRecord, error:Error)]()
        op.recordChangedBlock = { record in
            do {
                try deserializer.deserialize(record, applyOnlyChangedFields: false)
            }
            catch {
                changeFails.append((record:record, error:.UnderlyingError(error)))
                return
            }
        }
        
        var deletionFails = [(recordID:CKRecordID, error:Error)]()
        op.recordWithIDWasDeletedBlock = { deletedID in
            if let record = self.recordZoneRepository.recordRepository.record(ID:deletedID),
               let packageController = self.packageController,
               let deletedObj = packageController.objectWithIdentifier(record.recordID.recordName),
               let pkgC = deletedObj.controller?.packageController where pkgC == packageController { // package controller check is done because objectWithIdentifier can return an object from the shared database
                    deletedObj.deleteObject()
               }
            else {
                deletionFails.append((recordID:deletedID, Error.NoRecordToDeleteWithID(deletedID)))
            }
        }
        
        op.fetchRecordChangesCompletionBlock = { serverChangeToken, clientChangeTokenData, error in
            
            if let error = error {
                errorHandler(.UnderlyingError(error))
                return
            }
            
            guard let changeToken = serverChangeToken else {
                errorHandler(.MissingServerChangeToken(recordZone))
                return
            }
            
            state.setServerChangeToken(changeToken, forZoneID:recordZone.zoneID)
            
            completionHandler(failedChanges: changeFails, failedDeletions: deletionFails)
            
            do {
                try state.serialize()
                self.state = state
            }
            catch {
                DDLogError("ERROR: Failed to serialize server change token: \(error)")
            }
        }
        
        self.operationQueue.addOperation(op)
    }
    
    public typealias DatabasePackageMetadataListHandler = ([DatabasePackageMetadata]) -> Void
    
    public func availableDatabasePackages(completionHandler:DatabasePackageMetadataListHandler, errorHandler:ErrorHandler) {
        self.ensureUserAuthenticated({ ownerID in
            self._availableDatabasePackages(ownerID.recordName, completionHandler: completionHandler, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    public func _availableDatabasePackages(ownerName:String, completionHandler:DatabasePackageMetadataListHandler, errorHandler:ErrorHandler) {
        var packages = [DatabasePackageMetadata]()
        
        func recordFetchedHandler(record:CKRecord) {
            let package = DatabasePackageMetadata(recordID: record.recordID, title: record["title"] as? String ?? nil)
            packages.append(package)
        }

        func cursorHandler(cursor:CKQueryCursor?, error:NSError?) -> Void {
            if let error = error {
                errorHandler(.UnderlyingError(error))
                return
            }
            
            if let cursor = cursor {
                let op = CKQueryOperation(cursor: cursor)
                op.database = self.database
                op.recordFetchedBlock = recordFetchedHandler
                op.queryCompletionBlock = cursorHandler
                self.operationQueue.addOperation(op)
            }
            else {
                completionHandler(packages)
            }
        }

        let op = CKQueryOperation(query: CKQuery(recordType: "DatabasePackageMetadata", predicate: NSPredicate(value: true)))
        op.database = self.database
        op.zoneID = self.packageMetadataZoneID(ownerName:ownerName)
        op.recordFetchedBlock = recordFetchedHandler
        op.queryCompletionBlock = cursorHandler
        
        self.operationQueue.addOperation(op)
    }
    
    public typealias DatabasePackageMetadataHandler = (packageMetadata:CKRecord) -> Void
    
    private var packageMetadataZoneName:String {
        return "DatabasePackageMetadata"
    }
    
    private func packageMetadataZoneID(ownerName ownerName:String) -> CKRecordZoneID {
        return CKRecordZoneID(zoneName: self.packageMetadataZoneName, ownerName: ownerName)
    }
    
    public func ensureDatabasePackageMetadataExists(completionHandler:DatabasePackageMetadataHandler, errorHandler:ErrorHandler) {
        guard let packageController = self.packageController else {
            errorHandler(.NilPackageController)
            return
        }
        
        let identifier = packageController.identifier
        let packageMetadata = CKRecord(recordType: "DatabasePackageMetadata", recordID: CKRecordID(recordName: identifier, zoneID: CKRecordZone.defaultRecordZone().zoneID))
        packageMetadata["title"] = packageController.title
        
        let saveMetadata = CKModifyRecordsOperation(recordsToSave: [packageMetadata], recordIDsToDelete: nil)
        saveMetadata.database = self.database
        saveMetadata.savePolicy = .AllKeys
        
        self.operationQueue.addOperation(saveMetadata)
        
        saveMetadata.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            if let error = error {
                errorHandler(.UnderlyingError(error))
                return
            }
            
            guard let records = savedRecords, firstRecord = records.first where records.count == 1 else {
                errorHandler(Error.UnexpectedRecords(savedRecords))
                return
            }
            
            completionHandler(packageMetadata: firstRecord)
        }
    }
    
    public func synchronize(completionHandler:(errors:[Error])->Void) {
        self.pull { pullErrors in
            if (pullErrors.count > 0) {
                completionHandler(errors: pullErrors)
                return
            }
            
            self.push({ (savedRecords, saveFailures, deletedRecordIDs, deletionFailures, completeFailure) in
                var errors = [Error]()
                
                if let saveFailures = saveFailures {
                    errors.appendContentsOf(saveFailures.map { Error.UnderlyingError($0.error) })
                }
                
                if let deletionFailures = deletionFailures {
                    errors.appendContentsOf(deletionFailures.map { Error.UnderlyingError($0.error) })
                }
                
                if errors.count > 0 {
                    completionHandler(errors:errors)
                    return
                }
                
                self.ensureDatabasePackageMetadataExists({ packageMetadata in
                    completionHandler(errors:[])
                }) { err in
                    completionHandler(errors:[err])
                }
            }) { error in
                completionHandler(errors: [error])
            }
        }
    }
}
