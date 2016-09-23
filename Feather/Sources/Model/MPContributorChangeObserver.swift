//
//  MPContributorChangeObserver.swift
//  Feather
//
//  Created by Matias Piipari on 14/09/2016.
//  Copyright © 2016 Matias Piipari. All rights reserved.
//

import Foundation

/** Have classes which observe MPContributor changes conform to this protocol. That is, a class X whose instances x are sent
 
 packageController.notificationCenter.addObserver(x, forManagedObjectClass:MPSection.self)
 
 * should conform to this protocol.
 */

@objc(MPContributorChangeObserver) public protocol ContributorChangeObserver: MPManagedObjectChangeObserver {
    func didAddSection(notification:NSNotification)
    func didUpdateSection(notification:NSNotification)
    func didRemoveSection(notification:NSNotification)
}

@objc(MPContributorRecentChangeObserver) public protocol ContributorRecentChangeObserver: MPManagedObjectRecentChangeObserver {
    func hasAddedSection(notification:NSNotification)
    func hasUpdatedSection(notification:NSNotification)
    func hasRemovedSection(notification:NSNotification)
}
