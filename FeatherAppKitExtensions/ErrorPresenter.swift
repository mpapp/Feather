//
//  ErrorPresenter.swift
//  Feather
//
//  Created by Matias Piipari on 16/05/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

/// Formalises the NSResponder-like behaviour of responding to -presentError: for objects that don't subclass NSResponder.
public protocol ErrorPresenter {
    func presentError(_ error: Error) -> Bool
}

extension NSDocumentController: ErrorPresenter {
}

extension NSDocument: ErrorPresenter {
}

extension NSWindowController: ErrorPresenter {
}

extension NSViewController: ErrorPresenter {
}

