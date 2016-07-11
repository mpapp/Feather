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
        case UnexpectedPropertyValue(key:String, propertyKey:String, value:AnyObject, valueType:AnyClass)
        case MissingController(MPManagedObject)
        case UnexpectedReferenceValue(String)
    }
    
    public let ownerName:String
    public let recordZoneRepository:CloudKitRecordZoneRepository
    public let ignoredKeys:[String]
    
    public func serialize(object:MPManagedObject, serializingKey:String? = nil) throws -> CKRecord {
        let record = try self.recordZoneRepository.record(object:object, ownerName: ownerName)
        
        
        guard let doc = object.document else {
            throw Error.DocumentUnavailable(object)
        }
        
        for (key, value) in doc.userProperties {
            guard let keyString = key as? String else {
                throw Error.UnexpectedKey(key)
            }
            
            if self.ignoredKeys.contains(keyString) {
                continue
            }
            
            try self.refresh(record:record, withObject: object, key: keyString, value:value)
        }
        
        return record
    }
    
    private func refresh(record record:CKRecord, withObject object:MPManagedObject, key keyString:String, value:AnyObject) throws {
        
        let kvcKey = object.valueCodingKeyForPersistedPropertyKey(keyString)
        
        let val = object.valueForKey(kvcKey)
        
        switch val {
            
        case let valObj as MPManagedObject:
            let valRecord:CKRecord
            
            guard let valDocID = valObj.documentID else {
                break
            }
            
            let zone = try self.recordZoneRepository.recordZone(objectType: valObj.dynamicType, ownerName: ownerName)
            let valRecordID = CKRecordID(recordName: valDocID, zoneID:zone.zoneID)
            if let existingRecord = self.recordZoneRepository.recordRepository[valRecordID] {
                valRecord = existingRecord
            }
            else {
                valRecord = try self.serialize(valObj, serializingKey: kvcKey)
            }
            let valRef = CKReference(record: valRecord, action: .None)
            record.setObject(valRef, forKey: kvcKey)
            
        // unresolvable references (where object being referenced is nil at the moment) should still be stored as a CKReference.
        case nil where value is String && object.dynamicType.classOfProperty(kvcKey) is MPManagedObject.Type:
            guard let valueString = value as? String else {
                preconditionFailure("Logic error: value should be guaranteed to be a string in this case.")
            }
            
            guard let objType = MPManagedObject.managedObjectClassFromDocumentID(valueString) as? MPManagedObject.Type else {
                throw Error.UnexpectedReferenceValue(valueString)
            }
            
            let zone = try self.recordZoneRepository.recordZone(objectType: objType, ownerName: ownerName)
            let recordID = CKRecordID(recordName: valueString, zoneID: zone.zoneID)
            let reference = CKReference(recordID: recordID, action: .None)
            record.setObject(reference, forKey: keyString)
            
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
            if kvcKey == "prototype" {
                if let val = val {
                    precondition(val is MPManagedObject)
                }
            }
            print("object:\(object), keyString:\(keyString) value:\(value) (\(value.dynamicType)), val:\(val) (\(val.dynamicType))")

            throw Error.UnexpectedPropertyValue(key:kvcKey, propertyKey: keyString, value:value, valueType:value.dynamicType)
        }
    }
}
