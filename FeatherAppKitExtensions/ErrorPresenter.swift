//
//  ErrorPresenter.swift
//  Feather
//
//  Created by Matias Piipari on 16/05/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

// Needed because some objects that implement -presentError: are not subclassing NSResponder.
protocol ErrorPresenter {
    func presentError(error: NSError) -> Bool
}

extension NSDocument: ErrorPresenter {
    
}