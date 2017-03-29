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
    
    public enum Error:Error {
        case unexpectedModelClass(String)
        case noControllerForModelClass(AnyClass)
    }
    
    public let packageController:MPDatabasePackageController

    public func deserialize(_ record:CKRecord, applyOnlyChangedFields:Bool = false) throws -> MPManagedObject? {
        let obj:MPManagedObject?
        
        if let o = packageController.object(withIdentifier: record.recordID.recordName) {
            if let pkgC = o.controller?.packageController, pkgC == self.packageController {
                obj = o
            }
            else {
                obj = nil
            }
        }
        else {
            let modelClass:AnyClass = MPManagedObject.managedObjectClass(fromDocumentID: record.recordID.recordName)
            guard let moc = self.packageController.controller(forManagedObjectClass: modelClass) else {
                throw Error.noControllerForModelClass(modelClass)
            }
            obj = moc.newObject(of: modelClass)
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
    
    fileprivate func refresh(object obj:MPManagedObject, withRecord record:CKRecord, key kvcKey:String) throws {
        let val = record.object(forKey: kvcKey)
        let propertyKey = obj.persistedPropertyKey(forValueCodingKey: kvcKey)
        
        switch val {
        case nil:
            obj.setValue(nil, forKey: kvcKey)
            
        case let reference as CKReference:
            precondition(type(of: obj).class(ofProperty: kvcKey) is MPManagedObject.Type)
            obj.setValue(reference.recordID.recordName, ofProperty: propertyKey)
            
        case let referenceArray as [CKReference]:
            precondition(type(of: obj).class(ofProperty: kvcKey) is NSArray.Type)
            obj.setValue(referenceArray.map { $0.recordID.recordName }, ofProperty: propertyKey)
            break
            
        case let valString as String where type(of: obj).class(ofProperty: kvcKey) is MPEmbeddedObject.Type:
            let embObj = MPEmbeddedObject(jsonString: valString, embeddingObject: obj, embeddingKey: kvcKey)
            obj.setValue(embObj, ofProperty: propertyKey)
            
        case let valString as String where type(of: obj).class(ofProperty: kvcKey) is NSDictionary.Type:
            let dict = try NSDictionary.decode(fromJSONString: valString)
            obj.setValue(dict, ofProperty: propertyKey)
            
        case let valString as String where type(of: obj).class(ofProperty: kvcKey) is NSArray.Type:
            let array = try NSArray.decode(fromJSONString: valString)
            obj.setValue(array, ofProperty: propertyKey)
            
        case let valString as String where type(of: obj).class(ofProperty: kvcKey) is NSURL.Type:
            obj.setValue(valString, forKey: propertyKey)
            
        default:
            obj.setValue(val, forKey: kvcKey)
        }
        
        obj.cloudKitChangeTag = record.recordChangeTag
        
        obj.save()
    }
}
