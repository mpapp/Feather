//
//  FileManager+Extensions.swift
//  Feather
//
//  Created by Matias Piipari on 31/03/2017.
//  Copyright © 2017 Matias Piipari. All rights reserved.
//

import Foundation

public extension FileManager {
    
    enum TemporaryFileCreationError: Swift.Error {
        case noGroupCachesDirectory
    }
    
    func temporaryGroupCachesSubdirectoryURL(named name: String) throws -> URL {
        guard let groupCachesURL = self.sharedApplicationGroupCachesDirectoryURL() else {
            throw TemporaryFileCreationError.noGroupCachesDirectory
        }
        
        return try self.temporaryURL(inSubdirectoryNamed: name,
                                     at: groupCachesURL,
                                     createDirectory: true,
                                     createIntermediates: true,
                                     extension: "")
    }
    
    func temporaryGroupCachesFileURL(inSubdirectoryNamed name: String, pathExtension: String) throws -> URL {
        guard let groupCachesURL = self.sharedApplicationGroupCachesDirectoryURL() else {
            throw TemporaryFileCreationError.noGroupCachesDirectory
        }
        
        return try temporaryURL(inSubdirectoryNamed: name,
                                     at: groupCachesURL,
                                     createDirectory: false,
                                     createIntermediates: true,
                                     extension: pathExtension)
    }
    
}
