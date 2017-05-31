//
//  FeatherExtensionTests.swift
//  Feather
//
//  Created by Matias Piipari on 31/05/2017.
//  Copyright © 2017 Matias Piipari. All rights reserved.
//

import Foundation
import FeatherExtensions

class FeatherExtensionTests {
    
    func testStringAroundOccurrence() {
        XCTAssertEqual("foobar".stringAroundOccurrence(ofString: "oo", maxPadding: 1)!, "foob")
        XCTAssertEqual("oompa loompa".stringAroundOccurrence(ofString: "loo", maxPadding: 3)!, "pa loompa")
    }
    
    func testCollectionExtensions() {
        let chunks = [ "1", "2", "3",
                       "1", "2", "3",
                       "1", "2", "3",
                       "1", "2", "3" ].chunks(withDistance: 3)
        
        XCTAssertEqual(chunks.count, 4)
        for chunk in chunks { XCTAssertEqual(chunk, ["1", "2", "3"]) }
    }
    
}
