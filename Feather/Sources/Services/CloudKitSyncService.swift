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

public struct CloudKitSyncService {
    
    public enum Error: ErrorType {
        case NilState
        case OwnerUnknown
        case PartialError(CKErrorCode)
        case NoRecordToDeleteWithID(CKRecordID)
        case UnderlyingError(ErrorType)
        case MissingServerChangeToken(CKRecordZone)
        case UnexpectedRecords([CKRecord]?)
        case UnexpectedRecordZoneIDs([CKRecordZoneID]?)
    }
    
    private(set) public static var ownerID:CKRecordID?
    public let container:CKContainer
    public let database:CKDatabase
    public let recordZoneRepository:CloudKitRecordZoneRepository
    
    public typealias PackageIdentifier = String
    var state:[PackageIdentifier:CloudKitState] = [PackageIdentifier:CloudKitState]()
    
    public var ignoredKeys:[String]
    
    private let operationQueue:NSOperationQueue = NSOperationQueue()
    
    public init(container:CKContainer = CKContainer.defaultContainer(), database:CKDatabase = CKContainer.defaultContainer().privateCloudDatabase, packageIdentifier:PackageIdentifier, ignoredKeys:[String]) throws {
        self.recordZoneRepository = CloudKitRecordZoneRepository(zoneSuffix: packageIdentifier)
        self.ignoredKeys = ignoredKeys
        self.operationQueue.maxConcurrentOperationCount = 1
        self.container = container
        self.database = database
        
        precondition(self.database == self.container.privateCloudDatabase || self.database == self.container.publicCloudDatabase, "Database should be the container's public or private database but is not.")
        
        if #available(OSX 10.11, *) {
            NSNotificationCenter.defaultCenter().addObserverForName(CKAccountChangedNotification, object: nil, queue: NSOperationQueue.mainQueue()) { notification in
                DDLogInfo("Account changed: \(notification)")
            }
        }
    }
    
    private func allRecords(packageController:MPDatabasePackageController) throws -> [CKRecord] {
        guard let ownerName = self.dynamicType.ownerID?.recordName else {
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
    public static func ensureUserAuthenticated(container:CKContainer, completionHandler:UserAuthenticationCompletionHandler, errorHandler:ErrorHandler) {
        if let ownerID = self.ownerID {
            completionHandler(ownerID:ownerID)
            return
        }
        
        container.fetchUserRecordIDWithCompletionHandler() { recordID, error in
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
 
    public func recordZoneNames(packageController:MPDatabasePackageController) -> [String] {
        let zoneNames = MPManagedObject.subclasses().flatMap { cls -> String? in
            let moClass = cls as! MPManagedObject.Type
            if String(moClass).containsString("Mixin") {
                return nil
            }
            
            if packageController.controllerForManagedObjectClass(moClass) == nil {
                return nil
            }
            
            return (MPManagedObjectsController.equivalenceClassForManagedObjectClass(moClass) as! MPManagedObject.Type).recordZoneName()
        }
        
        return NSOrderedSet(array: zoneNames + [CloudKitDatabasePackageListingService.packageMetadataZoneName]).array as! [String]
    }
    
    public func recordZones(packageController:MPDatabasePackageController, ownerName:String) throws -> [CKRecordZone] {
        let zones = try MPManagedObject.subclasses().flatMap { cls -> CKRecordZone? in
            let moClass = cls as! MPManagedObject.Type
            if String(moClass).containsString("Mixin") {
                return nil
            }
            
            guard let _ = packageController.controllerForManagedObjectClass(moClass) else {
                return nil
            }
            
            let zone = try self.recordZoneRepository.recordZone(objectType: moClass, ownerName: ownerName)
            return zone
        }
        
        let packageMetadataZone = CKRecordZone(zoneID: CloudKitDatabasePackageListingService.packageMetadataZoneID(ownerName))
        return NSOrderedSet(array: zones + [packageMetadataZone]).array as! [CKRecordZone]
    }
    
    private var recordZonesChecked:[CKRecordZone]? = nil // Record zones created by the app won't change during app runtime. You may as well just check them once.
    
    public mutating func ensureRecordZonesExist(packageController:MPDatabasePackageController, completionHandler:(ownerID:CKRecordID, recordZones:[CKRecordZone])->Void, errorHandler:ErrorHandler) {
        CloudKitSyncService.ensureUserAuthenticated(self.container, completionHandler: { ownerID in
            if let recordZonesChecked = self.recordZonesChecked {
                completionHandler(ownerID: ownerID, recordZones: recordZonesChecked)
                return
            }
            
            self._ensureRecordZonesExist(packageController, ownerName:ownerID.recordName, completionHandler:{ recordZones in
                self.recordZonesChecked = recordZones
                completionHandler(ownerID:ownerID, recordZones: recordZones)
            }, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    private func _ensureRecordZonesExist(packageController:MPDatabasePackageController, ownerName:String, completionHandler:(recordZones:[CKRecordZone])->Void, errorHandler:ErrorHandler) {
        let op:CKModifyRecordZonesOperation
        do {
            op = CKModifyRecordZonesOperation(recordZonesToSave: try self.recordZones(packageController, ownerName:ownerName), recordZoneIDsToDelete: [])
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
    public typealias SubscriptionCompletionHandler = (savedSubscriptions:[CKSubscription], failedSubscriptions:[(subscription:CKSubscription, error:ErrorType)]?, error:ErrorType?) -> Void
    
    public mutating func ensureSubscriptionsExist(packageController:MPDatabasePackageController, completionHandler:SubscriptionCompletionHandler) {
        self.ensureRecordZonesExist(packageController, completionHandler: { ownerID, _ in
            self._ensureSubscriptionsExist(packageController, ownerName:ownerID.recordName, completionHandler: completionHandler)
        }) { err in
            completionHandler(savedSubscriptions: [], failedSubscriptions: nil, error: err)
        }
    }
    
    private func _ensureSubscriptionsExist(packageController:MPDatabasePackageController, ownerName:String, completionHandler:SubscriptionCompletionHandler) {
        let subscriptions:[CKSubscription]
        do {
            subscriptions = try self.recordZones(packageController, ownerName:ownerName).map { zone -> CKSubscription in
                return CKSubscription(zoneID: zone.zoneID, subscriptionID: "\(zone.zoneID.zoneName)-subscription", options: [])
            }
        }
        catch {
            completionHandler(savedSubscriptions: [], failedSubscriptions: nil, error: error)
            return
        }
        
        let save = CKModifySubscriptionsOperation(subscriptionsToSave: subscriptions, subscriptionIDsToDelete: [])
        save.database = self.database
        self.operationQueue.addOperation(save)
        
        save.modifySubscriptionsCompletionBlock = { savedSubscriptions, deletedSubscriptions, error in
            if let error = error {
                print(error)
                completionHandler(savedSubscriptions: savedSubscriptions ?? [], failedSubscriptions: nil, error: error)
            }
            else {
                completionHandler(savedSubscriptions: savedSubscriptions ?? [], failedSubscriptions: nil, error: nil)
            }
        }
    }
    
    public typealias PushCompletionHandler = (savedRecords:[CKRecord], saveFailures:[(record:CKRecord, error:ErrorType)]?, deletedRecordIDs:[CKRecordID], deletionFailures:[(recordID:CKRecordID, error:ErrorType)]?, errorHandler:ErrorType?)->Void
    
    public mutating func push(packageController:MPDatabasePackageController, completionHandler:PushCompletionHandler, errorHandler:ErrorHandler) {
        CloudKitSyncService.ensureUserAuthenticated(self.container, completionHandler: { ownerID in
            self._ensureRecordZonesExist(packageController, ownerName:ownerID.recordName, completionHandler: { recordZones in
                self._push(packageController, completionHandler:completionHandler, errorHandler: errorHandler)
            }, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    private func _push(packageController:MPDatabasePackageController, completionHandler:PushCompletionHandler, errorHandler:ErrorHandler) {
        var recordsMap = [CKRecordID:CKRecord]()
        let records:[CKRecord]
        do {
            records = try self.allRecords(packageController) // FIXME: push only records changed since last sync.
            for record in records { recordsMap[record.recordID] = record }
        }
        catch {
            errorHandler(.UnderlyingError(error))
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
    
    public mutating func pull(packageController:MPDatabasePackageController, completionHandler:([Error])->Void) {
        let grp = dispatch_group_create()
        
        dispatch_group_enter(grp) // 1 enter
        
        let errorQ = dispatch_queue_create("push-error-queue", nil)
        
        var errors = [Error]()
        
        self.ensureRecordZonesExist(packageController, completionHandler: { ownerID, recordZones in
            let recordZoneNames = recordZones.map { $0.zoneID.zoneName }
            
            DDLogDebug("Pulling from record zones: \(recordZoneNames)")
            for recordZone in recordZones {
                dispatch_group_enter(grp) // 2 enter
                self.pull(packageController, recordZone:recordZone, completionHandler: { failedChanges, failedDeletions in
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
    
    public mutating func pull(packageController:MPDatabasePackageController, recordZone:CKRecordZone, completionHandler:PullCompletionHandler, errorHandler:ErrorHandler) {
        self.ensureRecordZonesExist(packageController, completionHandler: { ownerID, _ in
            self._pull(packageController, ownerName:ownerID.recordName, recordZone: recordZone, completionHandler: completionHandler, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    private mutating func ensureStateInitialized(packageController:MPDatabasePackageController, ownerName:String, allowInitializing:Bool) throws {
        if self.state[packageController.identifier] == nil {
            if !allowInitializing {
                throw Error.NilState
            }
            
            let state = CloudKitState(ownerName: ownerName, packageController: packageController)
            do {
                self.state[packageController.identifier] = try state.deserialize()
            }
            catch {
                self.state[packageController.identifier] = state
            }
        }
    }
    
    public mutating func _pull(packageController:MPDatabasePackageController, ownerName:String, recordZone:CKRecordZone, completionHandler:PullCompletionHandler, errorHandler:ErrorHandler) {
        let fetchRecords = CKFetchRecordsOperation()
        fetchRecords.database = self.database
        
        let deserializer = CloudKitDeserializer(packageController: packageController)
        
        self.operationQueue.addOperation(fetchRecords)
        
        do {
            try self.ensureStateInitialized(packageController, ownerName:ownerName, allowInitializing: true)
        }
        catch {
            errorHandler(.UnderlyingError(error))
        }
        
        let prevChangeToken = self.state[packageController.identifier]?.serverChangeToken(forZoneID: recordZone.zoneID)
        let op = CKFetchRecordChangesOperation(recordZoneID: recordZone.zoneID, previousServerChangeToken:prevChangeToken)
        op.database = self.database
        
        var changeFails = [(record:CKRecord, error:Error)]()
        var deletionFails = [(recordID:CKRecordID, error:Error)]()
        
        func recordChanged(record:CKRecord) {
            do {
                try deserializer.deserialize(record, applyOnlyChangedFields: false)
            }
            catch {
                changeFails.append((record:record, error:.UnderlyingError(error)))
                return
            }
        }
        
        func recordWithIDWasDeleted(deletedID:CKRecordID) {
            if let record = self.recordZoneRepository.recordRepository.record(ID:deletedID),
               let deletedObj = packageController.objectWithIdentifier(record.recordID.recordName),
               let pkgC = deletedObj.controller?.packageController where pkgC == packageController { // package controller check is done because objectWithIdentifier can return an object from the shared database
                    deletedObj.deleteObject()
               }
            else {
                deletionFails.append((recordID:deletedID, Error.NoRecordToDeleteWithID(deletedID)))
            }
        }
        
        func fetchRecordChangesCompletion(serverChangeToken:CKServerChangeToken?, clientChangeTokenData:NSData?, error:NSError?) {
            if let error = error {
                errorHandler(.UnderlyingError(error))
                return
            }
            
            guard let changeToken = serverChangeToken else {
                errorHandler(.MissingServerChangeToken(recordZone))
                return
            }
            
            self.state[packageController.identifier]?.setServerChangeToken(changeToken, forZoneID:recordZone.zoneID)
            
            if op.moreComing {
                let op = CKFetchRecordChangesOperation(recordZoneID: recordZone.zoneID, previousServerChangeToken:prevChangeToken)
                op.database = self.database
                op.previousServerChangeToken = changeToken
                op.recordChangedBlock = recordChanged
                op.recordWithIDWasDeletedBlock = recordWithIDWasDeleted
                op.fetchRecordChangesCompletionBlock = fetchRecordChangesCompletion
                
                self.operationQueue.addOperation(op)
            }
            
            do {
                try self.ensureStateInitialized(packageController, ownerName:ownerName, allowInitializing:false)
                try self.state[packageController.identifier]?.serialize()
            }
            catch {
                errorHandler(.UnderlyingError(error))
                return
            }
            
            if !op.moreComing {
                completionHandler(failedChanges: changeFails, failedDeletions: deletionFails)
            }
        }
        
        op.recordChangedBlock = recordChanged
        op.recordWithIDWasDeletedBlock = recordWithIDWasDeleted
        op.fetchRecordChangesCompletionBlock = fetchRecordChangesCompletion
        
        self.operationQueue.addOperation(op)
    }
    
    public typealias DatabasePackageMetadataHandler = (packageMetadata:CKRecord) -> Void
        
    public mutating func ensureDatabasePackageMetadataExists(packageController:MPDatabasePackageController, completionHandler:DatabasePackageMetadataHandler, errorHandler:ErrorHandler) {
        CloudKitSyncService.ensureUserAuthenticated(self.container, completionHandler: { ownerID in
            self._ensureDatabasePackageMetadataExists(packageController, ownerName:ownerID.recordName, completionHandler: completionHandler, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    public func _ensureDatabasePackageMetadataExists(packageController:MPDatabasePackageController, ownerName:String, completionHandler:DatabasePackageMetadataHandler, errorHandler:ErrorHandler) {
        let identifier = packageController.identifier
        let packageMetadata = CKRecord(recordType: "DatabasePackageMetadata", recordID: CKRecordID(recordName: identifier, zoneID: CloudKitDatabasePackageListingService.packageMetadataZoneID(ownerName)))
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
    
    public typealias DeletedRecordZonesHandler = (deletedZoneIDs:[CKRecordZoneID])->Void
    
    public mutating func purge(packageController:MPDatabasePackageController, completionHandler:DeletedRecordZonesHandler, errorHandler:ErrorHandler) {
        CloudKitSyncService.ensureUserAuthenticated(container, completionHandler: { ownerID in
            self._purge(packageController, ownerName:ownerID.recordName, completionHandler: completionHandler, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    public func _purge(packageController:MPDatabasePackageController, ownerName:String, completionHandler:DeletedRecordZonesHandler, errorHandler:ErrorHandler) {
        let deleteZones:CKModifyRecordZonesOperation
        
        do {
            deleteZones = CKModifyRecordZonesOperation(recordZonesToSave: nil, recordZoneIDsToDelete: try self.recordZones(packageController, ownerName:ownerName).map { $0.zoneID })
        }
        catch {
            errorHandler(.UnderlyingError(error))
            return
        }
        
        self.operationQueue.addOperation(deleteZones)
        
        deleteZones.modifyRecordZonesCompletionBlock = { _, deletedIDs, error in
            if let error = error {
                errorHandler(.UnderlyingError(error))
                return
            }
            
            guard let deletedZoneIDs = deletedIDs else {
                errorHandler(Error.UnexpectedRecordZoneIDs(deletedIDs))
                return
            }
            
            completionHandler(deletedZoneIDs: deletedZoneIDs)
        }
    }
    
    public mutating func synchronize(packageController:MPDatabasePackageController, completionHandler:(errors:[Error])->Void) {
        self.pull(packageController) { pullErrors in
            if (pullErrors.count > 0) {
                completionHandler(errors: pullErrors)
                return
            }
            
            self.push(packageController, completionHandler:{ (savedRecords, saveFailures, deletedRecordIDs, deletionFailures, completeFailure) in
                var errors = [Error]()
                
                if let completeFailure = completeFailure {
                    errors.append(.UnderlyingError(completeFailure))
                }
                
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
                
                self.ensureDatabasePackageMetadataExists(packageController, completionHandler: { packageMetadata in
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
