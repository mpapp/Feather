//
//  MPPlaceHolding.h
//  Feather
//
//  Created by Matias Piipari on 10/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Foundation;

@protocol MPPlaceHolding <NSObject>

@property (readonly, copy, nonnull) NSString *placeholderString;

@end


@protocol MPMutablyPlaceHolding <MPPlaceHolding>

@property (readwrite, copy, nonnull) NSString *placeholderString;

@end

