//
//  CloudKitRecordRepository.swift
//  Feather
//
//  Created by Matias Piipari on 02/07/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation
import CloudKit

public struct CloudKitRecordRepository {
    
    fileprivate var recordMap:[CKRecordID: CKRecord] = [CKRecordID: CKRecord]()
    
    public mutating func add(record r:CKRecord) {
        recordMap[r.recordID] = r
    }
    
    public mutating func remove(record r:CKRecord) {
        recordMap.removeValue(forKey: r.recordID)
    }
    
    public func record(ID rID:CKRecordID) -> CKRecord? {
        return recordMap[rID]
    }
    
    subscript(recordID:CKRecordID) -> CKRecord? {
        get {
            return self.record(ID: recordID)
        }
    }
}

@objc open class CloudKitRecordZoneRepository: NSObject {
    
    fileprivate var recordZoneMap:[CKRecordZoneID: CKRecordZone] = [CKRecordZoneID: CKRecordZone]()
    fileprivate(set) open var recordRepository:CloudKitRecordRepository = CloudKitRecordRepository()
    open let zoneSuffix:String
    
    public init(zoneSuffix:String) {
        self.zoneSuffix = zoneSuffix
        super.init()
    }
    
    open func add(recordZone rz:CKRecordZone) {
        recordZoneMap[rz.zoneID] = rz
    }
    
    open func remove(record rz:CKRecordZone) {
        recordZoneMap.removeValue(forKey: rz.zoneID)
    }
    
    open func recordZone(ID rID:CKRecordZoneID) -> CKRecordZone? {
        return recordZoneMap[rID]
    }
    
    subscript(recordZoneID:CKRecordZoneID) -> CKRecordZone? {
        get {
            return self.recordZone(ID: recordZoneID)
        }
    }
    
    open func recordZoneID(objectType ot:MPManagedObject.Type, ownerName:String) -> CKRecordZoneID {
        return CKRecordZoneID(zoneName: ot.recordZoneName() + "-" + self.zoneSuffix, ownerName: ownerName)
    }
    
    open func recordID(forObject object:MPManagedObject, ownerName:String) throws -> CKRecordID {
        guard let recordName = object.documentID else {
            throw CloudKitSerializer.Error.objectDeleted(object)
        }
        return CKRecordID(recordName: recordName, zoneID: self.recordZoneID(objectType:type(of: object), ownerName: ownerName))
    }
    
    open func record(object o:MPManagedObject, ownerName:String) throws -> CKRecord {
        let recordID = try self.recordID(forObject:o, ownerName: ownerName)
        
        if let existingRecord = self.recordRepository[recordID] {
            return existingRecord
        }
        
        let record = CKRecord(recordType: type(of: o).recordType(), recordID: recordID)
        self.recordRepository.add(record: record)
        
        return record
    }
    
    open func recordZone(objectType ot:MPManagedObject.Type, ownerName:String) throws -> CKRecordZone {
        let recordZoneID = self.recordZoneID(objectType:ot, ownerName: ownerName)
        
        if let existingZone = self[recordZoneID] {
            return existingZone
        }
        
        let recordZone = CKRecordZone(zoneID: recordZoneID)
        self.add(recordZone: recordZone)
        
        return recordZone
    }
}
