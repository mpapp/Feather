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
    
    public enum Error: Swift.Error {
        case objectDeleted(MPManagedObject)
        case ownerDeleted(MPContributor)
        case documentUnavailable(MPManagedObject)
        case unexpectedKey(NSObject)
        case unexpectedPropertyValue(key:String, propertyKey:String, value:Any, valueType:Any.Type)
        case missingController(MPManagedObject)
        case unexpectedReferenceValue(String)
    }
    
    public let ownerName:String
    public let recordZoneRepository:CloudKitRecordZoneRepository
    
    public func serialize(_ object:MPManagedObject, serializingKey:String? = nil) throws -> CKRecord {
        let record = try self.recordZoneRepository.record(object:object, ownerName: ownerName)
        
        
        guard let doc = object.document else {
            throw Error.documentUnavailable(object)
        }
        
        for (key, value) in doc.userProperties {
            guard let keyString = key as? String else {
                throw Error.unexpectedKey(key as NSObject)
            }
            
            if type(of: object).cloudKitIgnoredKeys().contains(keyString) {
                continue
            }
            
            try self.refresh(record:record, withObject: object, key: keyString, value:value as Any)
        }
        
        return record
    }
    
    fileprivate func refresh(record:CKRecord, withObject object:MPManagedObject, key keyString:String, value: Any) throws {
        
        let kvcKey = object.valueCodingKey(forPersistedPropertyKey: keyString)
        
        let val = object.value(forKey: kvcKey)
        
        switch val {
            
        case let valObj as MPManagedObject:
            guard let valDocID = valObj.documentID else {
                break
            }
            
            let zone = try self.recordZoneRepository.recordZone(objectType: type(of: valObj), ownerName: ownerName)
            let valRecordID = CKRecordID(recordName: valDocID, zoneID:zone.zoneID)
            let valRef = CKReference(recordID: valRecordID, action: .none)
            record.setObject(valRef, forKey: kvcKey)
            
        // unresolvable references (where object being referenced is nil at the moment) should still be stored as a CKReference.
        case nil where value is String && type(of: object).class(ofProperty: kvcKey) is MPManagedObject.Type:
            guard let valueString = value as? String else {
                preconditionFailure("Logic error: value should be guaranteed to be a string in this case.")
            }
            
            guard let objType = MPManagedObject.managedObjectClass(fromDocumentID: valueString) as? MPManagedObject.Type else {
                throw Error.unexpectedReferenceValue(valueString)
            }
            
            let zone = try self.recordZoneRepository.recordZone(objectType: objType, ownerName: ownerName)
            let recordID = CKRecordID(recordName: valueString, zoneID: zone.zoneID)
            let reference = CKReference(recordID: recordID, action: .none)
            record.setObject(reference, forKey: keyString)
            
        case let embObj as MPEmbeddedObject:
            let embObjString = try embObj.jsonStringRepresentation()
            record.setObject(embObjString as CKRecordValue?, forKey: kvcKey)
            
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
                
                return CKReference(record: recordItem, action: CKReferenceAction.none)
            }
            record.setObject(references as CKRecordValue?, forKey: kvcKey)
            
        case let embeddedValues as [MPEmbeddedObject]:
            //print("\(kvcKey) => \(embeddedValues) (class:\(embeddedValues.dynamicType))")
            let embeddedValuesString = try (embeddedValues as NSArray).jsonStringRepresentation()
            record.setObject(embeddedValuesString as NSString as CKRecordValue, forKey: kvcKey)
            
        case let embeddedValueDict as [String:MPEmbeddedObject]:
            //print("\(kvcKey) => \(embeddedValueDict) (class:\(embeddedValueDict.dynamicType))")
            let embeddedValueDictString = try (embeddedValueDict as NSDictionary).jsonStringRepresentation()
            record.setObject(embeddedValueDictString as NSString as CKRecordValue, forKey: kvcKey)
            
        case let numberMap as [String:NSNumber]: // e.g. embeddedElementCounts, a map of document IDs to numbers
            let numberMapString = try (numberMap as NSDictionary).jsonStringRepresentation()
            record.setObject(numberMapString as NSString as CKRecordValue, forKey: kvcKey)
            
        case let valRecordValue as String:
            record.setObject(valRecordValue as NSString, forKey: kvcKey)
            
        case let valRecordValue as NSNumber:
            record.setObject(valRecordValue, forKey: kvcKey)
            
        case _ as URL where type(of: object).class(ofProperty: kvcKey) is NSURL.Type:
            guard let valueString = value as? String else {
                throw Error.unexpectedPropertyValue(key: kvcKey, propertyKey: keyString, value: value, valueType: type(of: value))
            }
            
            record.setObject(valueString as CKRecordValue?, forKey: kvcKey)

        case let valRecordValue as CKRecordValue:
            //print("\(kvcKey) => \(valRecordValue) (class:\(valRecordValue.dynamicType))")
            record.setObject(valRecordValue, forKey: kvcKey)
            

        default:
            if kvcKey == "prototype" {
                if let val = val {
                    precondition(val is MPManagedObject)
                }
            }
            
            #if DEBUG
            print("object:\(object), keyString:\(keyString) value:\(value) (\(type(of: value))), val:\(val ?? "nil") (\(type(of: val)))")
            #endif
            throw Error.unexpectedPropertyValue(key:kvcKey, propertyKey: keyString, value:value, valueType:type(of: value))
        }
    }
}
