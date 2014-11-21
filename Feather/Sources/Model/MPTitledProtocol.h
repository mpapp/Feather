//
//  MPTitledProtocol.h
//  Manuscripts
//
//  Created by Matias Piipari on 14/04/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MPTitledProtocol <NSObject>
@property (readwrite, copy) NSString *title;
@property (readwrite, copy) NSString *subtitle;
@property (readwrite, copy) NSString *desc;
@end
