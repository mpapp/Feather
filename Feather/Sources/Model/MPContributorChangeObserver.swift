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
    func didAddContributor(notification:NSNotification)
    func didUpdateContributor(notification:NSNotification)
    func didRemoveContributor(notification:NSNotification)
}

@objc(MPContributorRecentChangeObserver) public protocol ContributorRecentChangeObserver: MPManagedObjectRecentChangeObserver {
    func hasAddedContributor(notification:NSNotification)
    func hasUpdatedContributor(notification:NSNotification)
    func hasRemovedContributor(notification:NSNotification)
}
