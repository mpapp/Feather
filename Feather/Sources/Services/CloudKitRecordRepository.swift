//
//  CloudKitRecordRepository.swift
//  Feather
//
//  Created by Matias Piipari on 02/07/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation
import CloudKit

@objc public class CloudKitRecordRepository: NSObject {
    
    private var recordMap:[CKRecordID: CKRecord] = [CKRecordID: CKRecord]()
    
    public func add(record r:CKRecord) {
        recordMap[r.recordID] = r
    }
    
    public func remove(record r:CKRecord) {
        recordMap.removeValueForKey(r.recordID)
    }
    
    public func record(ID rID:CKRecordID) -> CKRecord? {
        return recordMap[rID]
    }
    
    subscript(recordID:CKRecordID) -> CKRecord? {
        get {
            return self.record(ID: recordID)
        }
    }
    
    public func recordZoneID(object:MPManagedObject, ownerName:String) throws -> CKRecordZoneID {
        return CKRecordZoneID(zoneName: object.dynamicType.recordZoneName(), ownerName: ownerName)
    }
    
    public func recordID(object:MPManagedObject, ownerName:String) throws -> CKRecordID {
        guard let recordName = object.documentID else {
            throw CloudKitSerializer.Error.ObjectDeleted(object)
        }
        return CKRecordID(recordName: recordName, zoneID: try self.recordZoneID(object, ownerName: ownerName))
    }
    
    public func record(object o:MPManagedObject, ownerName:String) throws -> CKRecord {
        let recordID = try self.recordID(o, ownerName: ownerName)
        
        if let existingRecord = self[recordID] {
            return existingRecord
        }
        
        
        let record = CKRecord(recordType: o.recordType, recordID: recordID)
        self.add(record: record)
        
        return record
    }
}
