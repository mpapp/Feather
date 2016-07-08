//
//  CloudKitDeserializer.swift
//  Feather
//
//  Created by Matias Piipari on 03/07/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation
import CloudKit
import CouchbaseLite
import Feather.MPManagedObject_Protected

public struct CloudKitDeserializer {
    
    public enum Error:ErrorType {
        case UnexpectedModelClass(String)
        case NoControllerForModelClass(AnyClass)
    }
    
    public let packageController:MPDatabasePackageController

    public func deserialize(record:CKRecord, applyOnlyChangedFields:Bool = false) throws -> MPManagedObject {
        let obj:MPManagedObject
        
        if let o = packageController.objectWithIdentifier(record.recordID.recordName) {
            obj = o
        }
        else {
            let modelClass:AnyClass = MPManagedObject.managedObjectClassFromDocumentID(record.recordID.recordName)
            guard let moc = self.packageController.controllerForManagedObjectClass(modelClass) else {
                throw Error.NoControllerForModelClass(modelClass)
            }
            obj = moc.newObjectOfClass(modelClass)
        }
        
        if applyOnlyChangedFields {
            for recordKey in record.changedKeys() {
                try self.refresh(object: obj, withRecord:record, key: recordKey)
            }
        }
        else {
            for recordKey in record.allKeys() {
                try self.refresh(object: obj, withRecord:record, key: recordKey)
            }
        }
        
        return obj
    }
    
    private func refresh(object object:MPManagedObject, withRecord record:CKRecord, key kvcKey:String) throws {
        let val = record.objectForKey(kvcKey)
        let propertyKey = object.persistedPropertyKeyForValueCodingKey(kvcKey)
        
        switch val {
        case nil:
            object.setValue(nil, forKey: kvcKey)
            
        case let reference as CKReference:
            precondition(object.dynamicType.classOfProperty(kvcKey) is MPManagedObject.Type)
            object.setValue(reference.recordID.recordName, ofProperty: propertyKey)
            
        case let referenceArray as [CKReference]:
            precondition(object.dynamicType.classOfProperty(kvcKey) is NSArray.Type)
            object.setValue(referenceArray.map { $0.recordID.recordName }, ofProperty: propertyKey)
            break
            
        case let valString as String where object.dynamicType.classOfProperty(kvcKey) is MPEmbeddedObject.Type:
            let embObj = MPEmbeddedObject(JSONString: valString, embeddingObject: object, embeddingKey: kvcKey)
            object.setValue(embObj, ofProperty: propertyKey)
            
        case let valString as String where object.dynamicType.classOfProperty(kvcKey) is NSDictionary.Type:
            let dict = try NSDictionary.decodeFromJSONString(valString)
            object.setValue(dict, ofProperty: propertyKey)
            
        case let valString as String where object.dynamicType.classOfProperty(kvcKey) is NSArray.Type:
            let array = try NSArray.decodeFromJSONString(valString)
            object.setValue(array, forKey: propertyKey)
            
        default:
            object.setValue(val, forKey: kvcKey)
        }
        
        object.cloudKitChangeTag = record.recordChangeTag
        
        object.saveObject()
    }
}
