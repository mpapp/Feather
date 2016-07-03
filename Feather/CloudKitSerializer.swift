//
//  CloudKitSerializer.swift
//  Feather
//
//  Created by Matias Piipari on 01/07/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation
import CloudKit
import CocoaLumberjackSwift

public struct CloudKitSerializer {
    
    public enum Error: ErrorType {
        case ObjectDeleted(MPManagedObject)
        case OwnerDeleted(MPContributor)
        case DocumentUnavailable(MPManagedObject)
        case UnexpectedKey(NSObject)
        case UnexpectedPropertyValue(key:String, value:AnyObject)
        case MissingController(MPManagedObject)
    }
    
    public let ownerName:String
    public let recordZoneRepository:CloudKitRecordZoneRepository
    
    public func serialize(object:MPManagedObject, serializingKey:String? = nil) throws -> CKRecord {
        let record = try self.recordZoneRepository.record(object:object, ownerName: ownerName)
        
        
        guard let doc = object.document else {
            throw Error.DocumentUnavailable(object)
        }
        
        for (key, value) in doc.userProperties {
            guard let keyString = key as? String else {
                throw Error.UnexpectedKey(key)
            }
            
            try self.refresh(record:record, withObject: object, key: keyString, value:value)
        }
        
        return record
    }
    
    private func refresh(record record:CKRecord, withObject object:MPManagedObject, key keyString:String, value:AnyObject) throws {
        //print("Object:\(object), key: \(kvcKey), recordID:\(recordID)")
        
        let recordID = record.recordID
        let kvcKey = object.valueCodingKeyForPersistedPropertyKey(keyString)
        let val = object.valueForKey(kvcKey)
        
        switch val {
            
        case let valObj as MPManagedObject:
            
            let valRecord:CKRecord
            if let existingRecord = self.recordZoneRepository.recordRepository[recordID] {
                valRecord = existingRecord
            }
            else {
                valRecord = try self.serialize(valObj, serializingKey: kvcKey)
            }
            let valRef = CKReference(record: valRecord, action: CKReferenceAction.None)
            record.setObject(valRef, forKey: kvcKey)
            
        case let embObj as MPEmbeddedObject:
            let embObjString = try embObj.JSONStringRepresentation()
            record.setObject(embObjString, forKey: kvcKey)
            
        case let valObjArray as [MPManagedObject]:
            let references = try valObjArray.map { vObj -> CKReference in
                let recordItemID = try self.recordZoneRepository.recordID(forObject:vObj, ownerName: ownerName)
                let recordItem:CKRecord
                if let existingRecord = self.recordZoneRepository.recordRepository[recordItemID] {
                    recordItem = existingRecord
                }
                else {
                    recordItem = try self.serialize(vObj, serializingKey:kvcKey)
                }
                
                return CKReference(record: recordItem, action: CKReferenceAction.None)
            }
            record.setObject(references, forKey: kvcKey)
            
        case let embeddedValues as [MPEmbeddedObject]:
            //print("\(kvcKey) => \(embeddedValues) (class:\(embeddedValues.dynamicType))")
            let embeddedValuesString = try (embeddedValues as NSArray).JSONStringRepresentation()
            record.setObject(embeddedValuesString, forKey: kvcKey)
            
        case let embeddedValueDict as [String:MPEmbeddedObject]:
            //print("\(kvcKey) => \(embeddedValueDict) (class:\(embeddedValueDict.dynamicType))")
            let embeddedValueDictString = try (embeddedValueDict as NSDictionary).JSONStringRepresentation()
            record.setObject(embeddedValueDictString, forKey: kvcKey)
            
        case let numberMap as [String:NSNumber]: // e.g. embeddedElementCounts, a map of document IDs to numbers
            let numberMapString = try (numberMap as NSDictionary).JSONStringRepresentation()
            record.setObject(numberMapString, forKey: kvcKey)
            
        case let valRecordValue as CKRecordValue:
            //print("\(kvcKey) => \(valRecordValue) (class:\(valRecordValue.dynamicType))")
            record.setObject(valRecordValue, forKey: kvcKey)
            
        default:
            throw Error.UnexpectedPropertyValue(key:kvcKey, value:value)
        }
    }
}
