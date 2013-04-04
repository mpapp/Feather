//
//  FeatherTests.h
//  FeatherTests
//
//  Created by Matias Piipari on 29/03/2013.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "Feather.h"

@interface MPFeatherTestSuite : SenTestCase <MPDatabasePackageControllerDelegate>
@property (copy) NSString *docRoot;
@end


@interface MPFeatherTestPackageController : MPShoeboxPackageController
+ (instancetype)sharedPackageController;
@end