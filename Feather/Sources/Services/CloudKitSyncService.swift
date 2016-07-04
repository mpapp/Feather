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
        case PartialError(CKErrorCode)
        case OwnerUnknown
        case UnderlyingError(ErrorType)
    }
    
    weak var packageController:MPDatabasePackageController?
    let container:CKContainer
    let recordZoneRepository:CloudKitRecordZoneRepository
    
    public var ownerID:CKRecordID? = nil {
        didSet {
            
        }
    }
    private let operationQueue:NSOperationQueue = NSOperationQueue()
    
    public init(packageController:MPDatabasePackageController, container:CKContainer? = CKContainer.defaultContainer()) {
        self.packageController = packageController
        self.container = container ?? CKContainer.defaultContainer()
        self.recordZoneRepository = CloudKitRecordZoneRepository(zoneSuffix: packageController.identifier)
        
        self.operationQueue.maxConcurrentOperationCount = 1
        
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
            
            return (MPManagedObjectsController.equivalenceClassForManagedObjectClass(moClass) as! MPManagedObject.Type).recordZoneName()
        }
        
        return NSOrderedSet(array: zoneNames).array as! [String]
    }
    
    public func recordZones(ownerName:String) throws -> [CKRecordZone] {
        let zones = try MPManagedObject.subclasses().flatMap { cls -> CKRecordZone? in
            let moClass = cls as! MPManagedObject.Type
            if String(moClass).containsString("Mixin") {
                return nil
            }
            
            let zone = try self.recordZoneRepository.recordZone(objectType: moClass, ownerName: ownerName)
            return zone
        }
        
        return NSOrderedSet(array: zones).array as! [CKRecordZone]
    }
    
    public func ensureRecordZonesExist(completionHandler:()->Void, errorHandler:ErrorHandler) {
        self.ensureUserAuthenticated({ ownerID in
            self._ensureRecordZonesExist(ownerID.recordName, completionHandler:completionHandler, errorHandler: errorHandler)
        }, errorHandler: errorHandler)
    }
    
    private func _ensureRecordZonesExist(ownerName:String, completionHandler:()->Void, errorHandler:ErrorHandler) {
        let op:CKModifyRecordZonesOperation
        do {
            op = CKModifyRecordZonesOperation(recordZonesToSave: try self.recordZones(ownerName), recordZoneIDsToDelete: [])
        }
        catch {
            errorHandler(Error.UnderlyingError(error))
            return
        }
        
        self.operationQueue.addOperation(op)
        
        op.modifyRecordZonesCompletionBlock = { savedRecordZones, deletedRecordZones, error in
            if let error = error {
                errorHandler(Error.UnderlyingError(error))
                return
            }
            
            completionHandler()
        }
    }
    
    public typealias ErrorHandler = (CloudKitSyncService.Error)->Void
    public typealias SubscriptionCompletionHandler = (savedSubscriptions:[CKSubscription], failedSubscriptions:[(subscription:CKSubscription, error:ErrorType)]?, completeFailure:ErrorType?) -> Void
    
    public func ensureSubscriptionsExist(completionHandler:SubscriptionCompletionHandler) {
        self.ensureUserAuthenticated({ ownerID in
            self.ensureRecordZonesExist({ 
                    self._ensureSubscriptionsExist(ownerID.recordName, completionHandler: completionHandler)
                }, errorHandler: { (err) in
                completionHandler(savedSubscriptions: [], failedSubscriptions: nil, completeFailure: err)
            })
        }) { err in
            completionHandler(savedSubscriptions: [], failedSubscriptions: nil, completeFailure: err)
        }
    }
    
    private func _ensureSubscriptionsExist(ownerName:String, completionHandler:SubscriptionCompletionHandler) {
        let subscriptions = self.recordZoneNames.map { zoneName -> CKSubscription in
            let zoneID = CKRecordZoneID(zoneName: zoneName, ownerName: ownerName)
            return CKSubscription(zoneID: zoneID, subscriptionID: "\(zoneName)-subscription", options: [])
        }
        
        let save = CKModifySubscriptionsOperation(subscriptionsToSave: subscriptions, subscriptionIDsToDelete: [])
        self.operationQueue.addOperation(save)
        
        save.modifySubscriptionsCompletionBlock = { savedSubscriptions, deletedSubscriptions, error in
            if let error = error {
                print(error)
                completionHandler(savedSubscriptions: savedSubscriptions ?? [], failedSubscriptions: nil, completeFailure: error)
            }
            else {
                completionHandler(savedSubscriptions: savedSubscriptions ?? [], failedSubscriptions: nil, completeFailure: nil)
            }
        }
    }
    
    public typealias PushCompletionHandler = (savedRecords:[CKRecord], saveFailures:[(record:CKRecord, error:ErrorType)]?, deletedRecordIDs:[CKRecordID], deletionFailures:[(recordID:CKRecordID, error:ErrorType)]?, completeFailure:ErrorType?)->Void
    
    public func push(completionHandler:PushCompletionHandler, errorHandler:ErrorHandler) {
        
        self.ensureUserAuthenticated({ ownerID in
            self._ensureRecordZonesExist(ownerID.recordName, completionHandler: { 
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
            completionHandler(savedRecords:[], saveFailures:nil, deletedRecordIDs:[], deletionFailures:nil, completeFailure:error)
            return
        }
        
        let save = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: [])
        save.savePolicy = CKRecordSavePolicy.AllKeys
        
        self.operationQueue.addOperation(save)
        
        // This block reports an error of type partialFailure when it saves or deletes only some of the records successfully. The userInfo dictionary of the error contains a CKPartialErrorsByItemIDKey key whose value is an NSDictionary object. The keys of that dictionary are the IDs of the records that were not saved or deleted, and the corresponding values are error objects containing information about what happened.
        save.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
            guard let err = error else {
                completionHandler(savedRecords: savedRecords ?? [], saveFailures: nil, deletedRecordIDs: deletedRecordIDs ?? [], deletionFailures: nil, completeFailure: nil)
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
                completionHandler(savedRecords: savedRecords ?? [], saveFailures:failedSaves, deletedRecordIDs: deletedRecordIDs ?? [], deletionFailures:nil, completeFailure: nil)
            }
            else {
                completionHandler(savedRecords: savedRecords ?? [], saveFailures:nil, deletedRecordIDs: deletedRecordIDs ?? [], deletionFailures: nil, completeFailure: err)
            }
        }
    }
    
    public func pull(ownerName:String, recordZone:CKRecordZone, completionHandler:()->Void, errorHandler:ErrorHandler) {
        let fetchRecords = CKFetchRecordsOperation()
        
        self.operationQueue.addOperation(fetchRecords)
        
        let op = CKFetchRecordChangesOperation(recordZoneID: recordZone.zoneID, previousServerChangeToken:nil)
        self.operationQueue.addOperation(op)
        
        op.recordChangedBlock = { record in
            if let obj = self.packageController?.objectWithIdentifier(record.recordID.recordName) {
                
            }
            
        }
        
        op.recordWithIDWasDeletedBlock = { deletedID in
            if let record = self.recordZoneRepository.recordRepository.record(ID:deletedID),
               let packageController = self.packageController,
               let deletedObj = packageController.objectWithIdentifier(record.recordID.recordName) {
                deletedObj.deleteObject()
            }
        }
        
        /*
        fetchRecords.perRecordCompletionBlock = { record, recordID, error in
            guard let record = record, rID = recordID  else {
                print("Error: \(error)")
                return
            }
            
            print("Record for \(rID): \(record)")
        }
        
        fetchRecords.fetchRecordsCompletionBlock = { recordMap, error in
            if let error = error {
                errorHandler(Error.UnderlyingError(error))
                return
            }
            
            completionHandler()
        }*/
    }
}
