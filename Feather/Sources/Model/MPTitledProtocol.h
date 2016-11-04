//
//  MPTitledProtocol.h
//  Manuscripts
//
//  Created by Matias Piipari on 14/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Foundation;

@protocol MPTitledProtocol <NSObject>
@property (readwrite, copy, nonnull) NSString *title;
@property (readwrite, copy, nullable) NSString *subtitle;
@property (readwrite, copy, nullable) NSString *desc;
@end
