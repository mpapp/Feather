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
    }
    
    weak var packageController:MPDatabasePackageController?
    let container:CKContainer
    
    public var ownerID:CKRecordID? = nil {
        didSet {
            
        }
    }
    private let operationQueue:NSOperationQueue = NSOperationQueue()
    
    public init(packageController:MPDatabasePackageController, container:CKContainer? = CKContainer.defaultContainer()) {
        self.packageController = packageController
        self.container = container ?? CKContainer.defaultContainer()
        
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

        let serializer = CloudKitSerializer(ownerName:ownerName)
        let records = try packageController.allObjects.map {
            try serializer.serialize($0)
        }
        
        return records
    }
    
     
    private var recordZoneNames:[String] {
        let zoneNames = MPManagedObject.subclasses().map { cls -> String in
            let moClass = cls as! MPManagedObject.Type
            return moClass.recordZoneName()
        }
        
        return NSOrderedSet(array: zoneNames).array as! [String]
    }
    
    private func ensureUserAuthenticated(completionHandler:()->Void, errorHandler:(ErrorType)->Void) {
        self.container.fetchUserRecordIDWithCompletionHandler() { recordID, error in
            if let error = error {
                errorHandler(error)
                return
            }
            else if let recordID = recordID {
                self.ownerID = recordID
                return
            }
            else {
                preconditionFailure("Both error and record were nil?")
            }
        }
    }
    
    public typealias ErrorHandler = (CloudKitSyncService.Error)->Void
    public typealias SubscriptionCompletionHandler = (savedSubscriptions:[CKSubscription], failedSubscriptions:[(subscription:CKSubscription, error:ErrorType)]?) -> Void
    
    public func subscribe(ownerName:String, commpletionHandler:SubscriptionCompletionHandler) {
        self.container.privateCloudDatabase
        
        let subscriptions = self.recordZoneNames.map { zoneName -> CKSubscription in
            let zoneID = CKRecordZoneID(zoneName: zoneName, ownerName: ownerName)
            return CKSubscription(zoneID: zoneID, subscriptionID: "\(zoneName)-subscription", options: CKSubscriptionOptions.FiresOnRecordUpdate.union(CKSubscriptionOptions.FiresOnRecordDeletion))
        }
        
        let save = CKModifySubscriptionsOperation(subscriptionsToSave: subscriptions, subscriptionIDsToDelete: [])
        self.operationQueue.addOperation(save)
        
        save.modifySubscriptionsCompletionBlock = { savedSubscriptions, deletedSubscriptions, error in
            
        }
    }
    
    public typealias PushCompletionHandler = (savedRecords:[CKRecord], saveFailures:[(record:CKRecord, error:ErrorType)]?, deletedRecordIDs:[CKRecordID], deletionFailures:[(recordID:CKRecordID, error:ErrorType)]?, completeFailure:ErrorType?)->Void
    
    public func push(completionHandler:PushCompletionHandler, errorHandler:ErrorHandler) {
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
            
            let partialErrorInfo = err.userInfo[CKPartialErrorsByItemIDKey] as! [CKRecordID:NSNumber]
            
            print("Partial error info: \(partialErrorInfo)")

            let failedSaves = partialErrorInfo.flatMap { (recordID, errorInfo) -> (record:CKRecord, error:ErrorType)? in
                // TODO: filter by error type
                if let record = recordsMap[recordID] {
                    return (record:record, error:Error.PartialError(CKErrorCode(rawValue: errorInfo.integerValue)!))
                }
                return nil
            }

            // TODO: handle failed partial deletions
            completionHandler(savedRecords: savedRecords ?? [], saveFailures:failedSaves, deletedRecordIDs: deletedRecordIDs ?? [], deletionFailures:nil, completeFailure: nil)
        }
    }
}

public struct CloudKitSerializer {
    
    public enum Error: ErrorType {
        case ObjectDeleted(MPManagedObject)
        case OwnerDeleted(MPContributor)
        case DocumentUnavailable(MPManagedObject)
        case UnexpectedKey(NSObject)
        case UnexpectedPropertyValue(AnyObject)
    }
    
    public let ownerName:String
    
    public func recordZoneID(object:MPManagedObject) -> CKRecordZoneID {
        return CKRecordZoneID(zoneName: object.dynamicType.recordZoneName(), ownerName: ownerName)
    }
    
    public func recordID(object:MPManagedObject) throws -> CKRecordID {
        guard let recordName = object.documentID else {
            throw Error.ObjectDeleted(object)
        }
        return CKRecordID(recordName: recordName, zoneID: self.recordZoneID(object))
    }
    
    public func serialize(object:MPManagedObject) throws -> CKRecord {
        let record = CKRecord(recordType: object.dynamicType.recordZoneName(), recordID: try self.recordID(object))
        
        guard let doc = object.document else {
            throw Error.DocumentUnavailable(object)
        }
        
        for (key, value) in doc.userProperties {
            guard let keyString = key as? String else {
                throw Error.UnexpectedKey(key)
            }
            
            let val = object.valueForKey(keyString), valObj = val as? MPManagedObject, valRecordValue = val as? CKRecordValue
            
            if let valObj = valObj {
                let valRecord = try self.serialize(valObj)
                let valRef = CKReference(record: valRecord, action: CKReferenceAction.None)
                record.setObject(valRef, forKey: keyString)
                continue
            }
            else if let valRecordValue = valRecordValue {
                record.setObject(valRecordValue, forKey: keyString)
            }
            else {
                throw Error.UnexpectedPropertyValue(value)
            }
        }
        
        return record
    }
}
