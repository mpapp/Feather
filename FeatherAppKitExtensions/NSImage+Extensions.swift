//
//  NSImage+Extensions.swift
//  Feather
//
//  Created by Matias Piipari on 31/03/2017.
//  Copyright © 2017 Matias Piipari. All rights reserved.
//

import Foundation

public extension NSImage {

    public enum ImageWritingError: Swift.Error {
        case cgImageCreationFailed
        case bitmapRepCreationFailed
        
    }
    
    func data(options: NSData.WritingOptions, type: NSBitmapImageFileType) throws -> Data {
        guard let cgRef = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImageWritingError.cgImageCreationFailed
        }
        
        let newRep = NSBitmapImageRep(cgImage: cgRef)
        newRep.size = self.size;   // if you want the same resolution
        
        guard let data = newRep.representation(using: type, properties: [:]) else {
            throw ImageWritingError.bitmapRepCreationFailed
        }
        
        return data
    }

}
