//
//  CachedProperty.swift
//  Feather
//
//  Created by Matias Piipari on 13/07/2019.
//  Copyright © 2019 Matias Piipari. All rights reserved.
//

import Foundation

/*
protocol CacheContainer {
    var propertyCache: NSDictionary { get }
}

@propertyWrapper struct CachedProperty<T> {
    private let key: String
    private let parent: CacheContainer
    
    init(parent: CacheContainer, key: String, initialValue: Any) {
        self.key = key
        parent.propertyCache.setValue(initialValue, forKey: key)
    }
    
    var wrappedValue: T {
        get {
            if let cachedValue = parent.propertyCache[key] {
                return cachedValue
            }
            return UserDefaults.standard.value(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: key)
        }
    }
}
 */
