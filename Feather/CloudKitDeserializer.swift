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

    public func deserialize(record:CKRecord, applyOnlyChangedFields:Bool = false) throws -> MPManagedObject? {
        let obj:MPManagedObject?
        
        if let o = packageController.objectWithIdentifier(record.recordID.recordName) {
            if let pkgC = o.controller?.packageController where pkgC == self.packageController {
                obj = o
            }
            else {
                obj = nil
            }
        }
        else {
            let modelClass:AnyClass = MPManagedObject.managedObjectClassFromDocumentID(record.recordID.recordName)
            guard let moc = self.packageController.controllerForManagedObjectClass(modelClass) else {
                throw Error.NoControllerForModelClass(modelClass)
            }
            obj = moc.newObjectOfClass(modelClass)
        }
        
        guard let object = obj else {
            return nil
        }
        
        if applyOnlyChangedFields {
            for recordKey in record.changedKeys() {
                try self.refresh(object: object, withRecord:record, key: recordKey)
            }
        }
        else {
            for recordKey in record.allKeys() {
                try self.refresh(object: object, withRecord:record, key: recordKey)
            }
        }
        
        return obj
    }
    
    private func refresh(object obj:MPManagedObject, withRecord record:CKRecord, key kvcKey:String) throws {
        let val = record.objectForKey(kvcKey)
        let propertyKey = obj.persistedPropertyKeyForValueCodingKey(kvcKey)
        
        switch val {
        case nil:
            obj.setValue(nil, forKey: kvcKey)
            
        case let reference as CKReference:
            precondition(obj.dynamicType.classOfProperty(kvcKey) is MPManagedObject.Type)
            obj.setValue(reference.recordID.recordName, ofProperty: propertyKey)
            
        case let referenceArray as [CKReference]:
            precondition(obj.dynamicType.classOfProperty(kvcKey) is NSArray.Type)
            obj.setValue(referenceArray.map { $0.recordID.recordName }, ofProperty: propertyKey)
            break
            
        case let valString as String where obj.dynamicType.classOfProperty(kvcKey) is MPEmbeddedObject.Type:
            let embObj = MPEmbeddedObject(JSONString: valString, embeddingObject: obj, embeddingKey: kvcKey)
            obj.setValue(embObj, ofProperty: propertyKey)
            
        case let valString as String where obj.dynamicType.classOfProperty(kvcKey) is NSDictionary.Type:
            let dict = try NSDictionary.decodeFromJSONString(valString)
            obj.setValue(dict, ofProperty: propertyKey)
            
        case let valString as String where obj.dynamicType.classOfProperty(kvcKey) is NSArray.Type:
            let array = try NSArray.decodeFromJSONString(valString)
            obj.setValue(array, ofProperty: propertyKey)
            
        case let valString as String where obj.dynamicType.classOfProperty(kvcKey) is NSURL.Type:
            obj.setValue(valString, forKey: propertyKey)
            
        default:
            obj.setValue(val, forKey: kvcKey)
        }
        
        obj.cloudKitChangeTag = record.recordChangeTag
        
        obj.saveObject()
    }
}
