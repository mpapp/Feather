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
import FeatherExtensions

public class CloudKitSyncService {
    
    public indirect enum Error: Swift.Error {
        case nilState
        case ownerUnknown
        case partialError(CKError)
        case noRecordToDeleteWithID(CKRecordID)
        case underlyingError(Swift.Error)
        case missingServerChangeToken(CKRecordZone)
        case unexpectedRecords([CKRecord]?)
        case unexpectedRecordZoneIDs([CKRecordZoneID]?)
        case compoundError([Error])
    }
    
    fileprivate(set) public static var ownerID:CKRecordID?
    public let container:CKContainer
    public let database:CKDatabase
    public let recordZoneRepository:CloudKitRecordZoneRepository
    
    public typealias PackageIdentifier = String
    var state:[PackageIdentifier:CloudKitState] = [PackageIdentifier:CloudKitState]()
    
    fileprivate let operationQueue:OperationQueue = OperationQueue()
    
    public init(container:CKContainer = CKContainer.default(), database:CKDatabase = CKContainer.default().privateCloudDatabase, packageIdentifier:PackageIdentifier) throws {
        self.recordZoneRepository = CloudKitRecordZoneRepository(zoneSuffix: packageIdentifier)
        self.operationQueue.maxConcurrentOperationCount = 1
        self.container = container
        self.database = database
        
        precondition(self.database == self.container.privateCloudDatabase || self.database == self.container.publicCloudDatabase, "Database should be the container's public or private database but is not.")
        
        if #available(OSX 10.11, *) {
            NotificationCenter.default.addObserver(forName: NSNotification.Name.CKAccountChanged, object: nil, queue: OperationQueue.main) { notification in
                DDLogInfo(logText: "Account changed: \(notification)")
            }
        }
    }
    
    public func allRecords(_ packageController:MPDatabasePackageController) throws -> [CKRecord] {
        guard let ownerName = type(of: self).ownerID?.recordName else {
            throw Error.ownerUnknown
        }

        let serializer = CloudKitSerializer(ownerName:ownerName, recordZoneRepository: self.recordZoneRepository)
        
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
    
    public typealias UserAuthenticationCompletionHandler = (_ ownerID:CKRecordID)->Void
    public static func ensureUserAuthenticated(_ container:CKContainer, completionHandler:@escaping UserAuthenticationCompletionHandler, errorHandler:@escaping ErrorHandler) {
        if let ownerID = self.ownerID {
            completionHandler(ownerID)
            return
        }
        
        container.fetchUserRecordID() { recordID, error in
            if let error = error {
                errorHandler(Error.underlyingError(error))
                return
            }
            else if let recordID = recordID {
                self.ownerID = recordID
                completionHandler(recordID)
                return
            }
            else {
                preconditionFailure("Both error and record were nil?")
            }
        }
    }
 
    public func recordZoneNames(_ packageController:MPDatabasePackageController) -> [String] {
        let zoneNames = MPManagedObject.subclasses().flatMap { cls -> String? in
            let moClass = cls as! MPManagedObject.Type
            if String(describing: moClass).contains("Mixin") {
                return nil
            }
            
            if packageController.controller(forManagedObjectClass: moClass) == nil {
                return nil
            }
            
            return (MPManagedObjectsController.equivalenceClass(forManagedObjectClass: moClass) as! MPManagedObject.Type).recordZoneName()
        }
        
        return NSOrderedSet(array: zoneNames + [CloudKitDatabasePackageListingService.packageMetadataZoneName]).array as! [String]
    }
    
    public func recordZones(_ packageController:MPDatabasePackageController, ownerName:String) throws -> [CKRecordZone] {
        let zones = try MPManagedObject.subclasses().flatMap { cls -> CKRecordZone? in
            let moClass = cls as! MPManagedObject.Type
            if String(describing: moClass).contains("Mixin") {
                return nil
            }
            
            guard let _ = packageController.controller(forManagedObjectClass: moClass) else {
                return nil
            }
            
            let zone = try self.recordZoneRepository.recordZone(objectType: moClass, ownerName: ownerName)
            return zone
        }
        
        let packageMetadataZone = CKRecordZone(zoneID: CloudKitDatabasePackageListingService.packageMetadataZoneID(ownerName))
        return NSOrderedSet(array: zones + [packageMetadataZone]).array as! [CKRecordZone]
    }
    
    fileprivate var recordZonesChecked:[CKRecordZone]? = nil // Record zones created by the app won't change during app runtime. You may as well just check them once.
    
    public func ensureRecordZonesExist(_ packageController:MPDatabasePackageController, completionHandler:@escaping (_ ownerID:CKRecordID, _ recordZones:[CKRecordZone])->Void, errorHandler:@escaping ErrorHandler) {
        CloudKitSyncService.ensureUserAuthenticated(self.container, completionHandler: { ownerID in
            if let recordZonesChecked = self.recordZonesChecked {
                completionHandler(ownerID, recordZonesChecked)
                return
            }
            
            self._ensureRecordZonesExist(packageController, ownerName:ownerID.recordName, completionHandler:{ recordZones in
                self.recordZonesChecked = recordZones
                completionHandler(ownerID, recordZones)
            }, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    fileprivate func _ensureRecordZonesExist(_ packageController:MPDatabasePackageController, ownerName:String, completionHandler:@escaping (_ recordZones:[CKRecordZone])->Void, errorHandler:@escaping ErrorHandler) {
        let op:CKModifyRecordZonesOperation
        do {
            op = CKModifyRecordZonesOperation(recordZonesToSave: try self.recordZones(packageController, ownerName:ownerName), recordZoneIDsToDelete: [])
            op.database = self.database
        }
        catch {
            errorHandler(.underlyingError(error))
            return
        }
        
        self.operationQueue.addOperation(op)
        
        op.modifyRecordZonesCompletionBlock = { savedRecordZones, deletedRecordZones, error in
            if let error = error {
                errorHandler(.underlyingError(error))
                return
            }
            
            guard let recordZones = savedRecordZones else {
                preconditionFailure("Unexpectedly no saved record zones although no error occurred.")
            }
            
            completionHandler(recordZones)
        }
    }
    
    public typealias ErrorHandler = (CloudKitSyncService.Error)->Void
    public typealias SubscriptionCompletionHandler = (_ savedSubscriptions:[CKSubscription], _ failedSubscriptions:[(subscription:CKSubscription, error:Error)]?, _ error:Error?) -> Void
    
    public func ensureSubscriptionsExist(_ packageController:MPDatabasePackageController,
                                                  completionHandler:@escaping SubscriptionCompletionHandler) {
        self.ensureRecordZonesExist(packageController, completionHandler: { ownerID, _ in
            self._ensureSubscriptionsExist(packageController, ownerName:ownerID.recordName, completionHandler: completionHandler)
        }) { err in
            completionHandler([], nil, err)
        }
    }
    
    fileprivate func _ensureSubscriptionsExist(_ packageController:MPDatabasePackageController, ownerName:String, completionHandler:@escaping SubscriptionCompletionHandler) {
        let subscriptions:[CKSubscription]
        do {
            subscriptions = try self.recordZones(packageController, ownerName:ownerName).map { zone -> CKSubscription in
                return CKSubscription(zoneID: zone.zoneID, subscriptionID: "\(zone.zoneID.zoneName)-subscription", options: [])
            }
        }
        catch {
            completionHandler([], nil, .underlyingError(error))
            return
        }
        
        let save = CKModifySubscriptionsOperation(subscriptionsToSave: subscriptions, subscriptionIDsToDelete: [])
        save.database = self.database
        self.operationQueue.addOperation(save)
        
        save.modifySubscriptionsCompletionBlock = { savedSubscriptions, deletedSubscriptions, error in
            if let error = error {
                print(error)
                completionHandler(savedSubscriptions ?? [], nil, .underlyingError(error))
            }
            else {
                completionHandler(savedSubscriptions ?? [], nil, nil)
            }
        }
    }
    
    public typealias PushCompletionHandler = (_ savedRecords:[CKRecord], _ saveFailures:[(record:CKRecord, error:Error)]?, _ deletedRecordIDs:[CKRecordID], _ deletionFailures:[(recordID:CKRecordID, error:Error)]?, _ errorHandler:Error?)->Void
    
    public func push(_ packageController:MPDatabasePackageController, completionHandler:@escaping PushCompletionHandler, errorHandler:@escaping ErrorHandler) {
        CloudKitSyncService.ensureUserAuthenticated(self.container, completionHandler: { ownerID in
            self._ensureRecordZonesExist(packageController, ownerName:ownerID.recordName, completionHandler: { recordZones in
                self._push(packageController, completionHandler:completionHandler, errorHandler: errorHandler)
            }, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    fileprivate func _push(_ packageController:MPDatabasePackageController, completionHandler:@escaping PushCompletionHandler, errorHandler:ErrorHandler) {
        var recordsMap = [CKRecordID:CKRecord]()
        let records:[CKRecord]
        do {
            records = try self.allRecords(packageController) // FIXME: push only records changed since last sync.
            for record in records { recordsMap[record.recordID] = record }
        }
        catch {
            errorHandler(.underlyingError(error))
            return
        }
        
        // FIXME: propagate deletions made since last sync.
        
        let grp = DispatchGroup()
        
        var allSuccessfulSaves = [CKRecord]()
        var allFailedSaves = [(record:CKRecord, error:Error)]()
        var allSuccessfulDeletions = [CKRecordID]()
        var completeFailures = [Error]()
        //var allFailedDeletions = [(recordID:CKRecordID, error:ErrorType)]()
        
        var completionHandlerCalled = false
        
        for recordChunk in records.chunks(withDistance: 100) {
       
            grp.enter()
            
            let save = CKModifyRecordsOperation(recordsToSave: recordChunk, recordIDsToDelete: [])
            save.savePolicy = CKRecordSavePolicy.allKeys
            save.database = self.database
            
            self.operationQueue.addOperation(save)
            
            // This block reports an error of type partialFailure when it saves or deletes only some of the records successfully. The userInfo dictionary of the error contains a CKPartialErrorsByItemIDKey key whose value is an NSDictionary object. The keys of that dictionary are the IDs of the records that were not saved or deleted, and the corresponding values are error objects containing information about what happened.
            save.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
                guard let nonNilErr = error else {
                    allSuccessfulSaves.append(contentsOf: savedRecords ?? [])
                    allSuccessfulDeletions.append(contentsOf: deletedRecordIDs ?? [])
                    completionHandler(savedRecords ?? [],
                                      nil,
                                      deletedRecordIDs ?? [],
                                      nil,
                                      nil)
                    completionHandlerCalled = true
                    grp.leave()
                    return
                }
                
                let err = nonNilErr as NSError
                
                print("Error: \(err), \(err.userInfo), \(err.userInfo[CKPartialErrorsByItemIDKey] ?? "(no partial errors)")")
                if let partialErrorInfo = err.userInfo[CKPartialErrorsByItemIDKey] as? [CKRecordID:NSError] {
                    
                    print("Partial error info: \(partialErrorInfo)")
                    
                    let failedSaves = partialErrorInfo.flatMap { (recordID, errorInfo) -> (record:CKRecord, error:Error)? in
                        // TODO: filter by error type
                        if let record = recordsMap[recordID] {
                            return (record:record, error:Error.underlyingError(errorInfo))
                        }
                        return nil
                    }
                    
                    allFailedSaves.append(contentsOf: failedSaves)
                    // TODO: handle also deletion failures.
                    // TODO: handle partial failures by retrying them in case the issue is due to something recoverable.
                }
                else {
                    completeFailures.append(.underlyingError(err))
                }
                
                grp.leave()
            }
        }
        
        if !completionHandlerCalled {
            grp.notify(queue: DispatchQueue.main) {
                completionHandler(allSuccessfulSaves,
                                  allFailedSaves,
                                  allSuccessfulDeletions,
                                  nil,
                                  completeFailures.count > 0 ? Error.compoundError(completeFailures) : nil)
            }
        }
    }
    
    public typealias PullCompletionHandler = (_ failedChanges:[(record:CKRecord, error:Error)]?, _ failedDeletions:[(recordID:CKRecordID, error:Error)]?)->Void
    
    public func pull(_ packageController:MPDatabasePackageController, completionHandler:@escaping ([Error])->Void) {
        let grp = DispatchGroup()
        
        grp.enter() // 1 enter
        
        let errorQ = DispatchQueue(label: "push-error-queue", attributes: [])
        
        var errors = [Error]()
        
        self.ensureRecordZonesExist(packageController, completionHandler: { ownerID, recordZones in
            let recordZoneNames = recordZones.map { $0.zoneID.zoneName }
            
            DDLogDebug(logText: "Pulling from record zones: \(recordZoneNames)")
            for recordZone in recordZones {
                grp.enter() // 2 enter
                self.pull(packageController, recordZone:recordZone, completionHandler: { failedChanges, failedDeletions in
                    for failedChange in failedChanges ?? [] {
                        errorQ.sync {
                            errors.append(failedChange.error)
                        }
                    }
                
                    for failedDeletion in failedDeletions ?? [] {
                        errorQ.sync {
                            errors.append(failedDeletion.error)
                        }
                    }
                    
                    grp.leave() // 2A leave
                    }, errorHandler: { error in
                        errorQ.sync {
                            errors.append(error)
                        }
                    grp.leave() // 2B leave
                })
            }
            
            grp.leave() // 1A leave

        }) { error in
            errorQ.sync {
                errors.append(.underlyingError(error))
            }
            grp.leave() // 1B leave
            return
        }
        
        grp.notify(queue: DispatchQueue.main) { 
            completionHandler(errors)
        }
    }
    
    public func pull(_ packageController:MPDatabasePackageController,
                     recordZone:CKRecordZone,
                     useServerToken:Bool = true,
                     completionHandler:@escaping PullCompletionHandler,
                     errorHandler:@escaping ErrorHandler) {
        self.ensureRecordZonesExist(packageController, completionHandler: { ownerID, _ in
            self._pull(packageController, ownerName:ownerID.recordName, recordZone: recordZone, useServerToken: useServerToken, completionHandler: completionHandler, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    fileprivate func ensureStateInitialized(_ packageController:MPDatabasePackageController, ownerName:String, allowInitializing:Bool) throws {
        if self.state[packageController.identifier] == nil {
            if !allowInitializing {
                throw Error.nilState
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
    
    public func _pull(_ packageController:MPDatabasePackageController,
                      ownerName:String, recordZone:CKRecordZone,
                      useServerToken:Bool,
                      completionHandler:@escaping PullCompletionHandler,
                      errorHandler:@escaping ErrorHandler) {
        let fetchRecords = CKFetchRecordsOperation()
        fetchRecords.database = self.database
        
        let deserializer = CloudKitDeserializer(packageController: packageController)
        
        self.operationQueue.addOperation(fetchRecords)
        
        do {
            try self.ensureStateInitialized(packageController, ownerName:ownerName, allowInitializing: true)
        }
        catch {
            errorHandler(.underlyingError(error))
        }
        
        let prevChangeToken = useServerToken ? self.state[packageController.identifier]?.serverChangeToken(forZoneID: recordZone.zoneID) : nil
        let op = CKFetchRecordChangesOperation(recordZoneID: recordZone.zoneID, previousServerChangeToken:prevChangeToken)
        op.database = self.database
        
        var changeFails = [(record:CKRecord, error:Error)]()
        var deletionFails = [(recordID:CKRecordID, error:Error)]()
        
        func recordChanged(_ record:CKRecord) {
            do {
                _ = try deserializer.deserialize(record, applyOnlyChangedFields: false)
            }
            catch {
                changeFails.append((record:record, error:.underlyingError(error as! CloudKitSyncService.Error)))
                return
            }
        }
        
        func recordWithIDWasDeleted(_ deletedID:CKRecordID) {
            if let record = self.recordZoneRepository.recordRepository.record(ID:deletedID),
               let deletedObj = packageController.object(withIdentifier: record.recordID.recordName),
               let pkgC = deletedObj.controller?.packageController, pkgC == packageController { // package controller check is done because objectWithIdentifier can return an object from the shared database
                    deletedObj.delete()
               }
            else {
                deletionFails.append((recordID:deletedID, Error.noRecordToDeleteWithID(deletedID)))
            }
        }
        
        func fetchRecordChangesCompletion(_ serverChangeToken:CKServerChangeToken?,
                                          clientChangeTokenData:Data?,
                                          error:Swift.Error?) {
            if let error = error {
                errorHandler(.underlyingError(error))
                return
            }
            
            guard let changeToken = serverChangeToken else {
                errorHandler(.missingServerChangeToken(recordZone))
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
                errorHandler(.underlyingError(error))
                return
            }
            
            if !op.moreComing {
                completionHandler(changeFails, deletionFails)
            }
        }
        
        op.recordChangedBlock = recordChanged
        op.recordWithIDWasDeletedBlock = recordWithIDWasDeleted
        op.fetchRecordChangesCompletionBlock = fetchRecordChangesCompletion
        
        self.operationQueue.addOperation(op)
    }
    
    public typealias DatabasePackageMetadataHandler = (_ packageMetadata:CKRecord) -> Void
        
    public func ensureDatabasePackageMetadataExists(_ packageController:MPDatabasePackageController,
                                                    completionHandler:@escaping DatabasePackageMetadataHandler,
                                                    errorHandler:@escaping ErrorHandler) {
        CloudKitSyncService.ensureUserAuthenticated(self.container, completionHandler: { ownerID in
            self._ensureDatabasePackageMetadataExists(packageController, ownerName:ownerID.recordName, completionHandler: completionHandler, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    public func _ensureDatabasePackageMetadataExists(_ packageController:MPDatabasePackageController, ownerName:String, completionHandler:@escaping DatabasePackageMetadataHandler, errorHandler:@escaping ErrorHandler) {
        let identifier = packageController.identifier
        let packageMetadata = CKRecord(recordType: "DatabasePackageMetadata", recordID: CKRecordID(recordName: identifier, zoneID: CloudKitDatabasePackageListingService.packageMetadataZoneID(ownerName)))
        packageMetadata["title"] = (packageController.title ?? "") as NSString as CKRecordValue
        
        let saveMetadata = CKModifyRecordsOperation(recordsToSave: [packageMetadata], recordIDsToDelete: nil)
        saveMetadata.database = self.database
        saveMetadata.savePolicy = .allKeys
        
        self.operationQueue.addOperation(saveMetadata)
        
        saveMetadata.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            if let error = error {
                errorHandler(.underlyingError(error))
                return
            }
            
            guard let records = savedRecords, let firstRecord = records.first, records.count == 1 else {
                errorHandler(Error.unexpectedRecords(savedRecords))
                return
            }
            
            completionHandler(firstRecord)
        }
    }
    
    public typealias DeletedRecordZonesHandler = (_ deletedZoneIDs:[CKRecordZoneID])->Void
    
    public func purge(_ packageController:MPDatabasePackageController,
                      recordIDs:[CKRecordID],
                      completionHandler:@escaping DeletedRecordZonesHandler,
                      errorHandler:@escaping ErrorHandler) {
        CloudKitSyncService.ensureUserAuthenticated(container, completionHandler: { ownerID in
            self._purge(packageController, ownerName:ownerID.recordName, recordIDs:recordIDs, completionHandler: completionHandler, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    public func _purge(_ packageController:MPDatabasePackageController, ownerName:String, recordIDs:[CKRecordID], completionHandler:@escaping DeletedRecordZonesHandler, errorHandler:@escaping ErrorHandler) {
        
        self.pull(packageController) { errors in
            if errors.count > 0 {
                errorHandler(Error.compoundError(errors))
                return
            }
            
            let deleteZones:CKModifyRecordZonesOperation
            
            do {
                deleteZones = CKModifyRecordZonesOperation(recordZonesToSave: nil, recordZoneIDsToDelete: try self.recordZones(packageController, ownerName:ownerName).map { $0.zoneID })
            }
            catch {
                errorHandler(.underlyingError(error))
                return
            }
            
            self.operationQueue.addOperation(deleteZones)
            
            deleteZones.modifyRecordZonesCompletionBlock = { _, deletedIDs, error in
                if let error = error {
                    errorHandler(.underlyingError(error))
                    return
                }
                
                guard let deletedZoneIDs = deletedIDs else {
                    errorHandler(Error.unexpectedRecordZoneIDs(deletedIDs))
                    return
                }
                
                completionHandler(deletedZoneIDs)
            }
        }
    }
    
    public func synchronize(_ packageController:MPDatabasePackageController, completionHandler:@escaping (_ errors:[Error])->Void) {
        self.pull(packageController) { pullErrors in
            if (pullErrors.count > 0) {
                completionHandler(pullErrors)
                return
            }
            
            self.push(packageController, completionHandler:{ (savedRecords, saveFailures, deletedRecordIDs, deletionFailures, completeFailure) in
                var errors = [Error]()
                
                if let completeFailure = completeFailure {
                    errors.append(.underlyingError(completeFailure))
                }
                
                if let saveFailures = saveFailures {
                    errors.append(contentsOf: saveFailures.map { Error.underlyingError($0.error) })
                }
                
                if let deletionFailures = deletionFailures {
                    errors.append(contentsOf: deletionFailures.map { Error.underlyingError($0.error) })
                }
                
                if errors.count > 0 {
                    completionHandler(errors)
                    return
                }
                
                self.ensureDatabasePackageMetadataExists(packageController, completionHandler: { packageMetadata in
                    completionHandler([])
                }) { err in
                    completionHandler([err])
                }
            }) { error in
                completionHandler([error])
            }
        }
    }
}
