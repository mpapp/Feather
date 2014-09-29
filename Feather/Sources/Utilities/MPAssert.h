//
//  MPAssert.h
//  Feather
//
//  Created by Markus Piipari on 27/09/14.
//  Copyright (c) 2014 Matias Piipari. All rights reserved.
//

#ifndef Feather_MPAssert_h
#define Feather_MPAssert_h

#define MPAssertNotNil(object) NSAssert(((object) != nil), @"Unexpectedly, %s is nil", #object)
#define MPAssertNil(object) NSAssert(((object) == nil), @"Unexpectedly, %s is not nil", #object)
#define MPAssertTrue(expr) NSAssert((expr), @"Unexpectedly, %s is false", #expr)
#define MPAssertFalse(expr) NSAssert((!(expr)), @"Unexpectedly, %s is true", #expr)

#define MPCAssertNotNil(object) NSCAssert(((object) != nil), @"Unexpectedly, %s is nil", #object)
#define MPCAssertNil(object) NSCAssert(((object) == nil), @"Unexpectedly, %s is not nil", #object)
#define MPCAssertTrue(expr) NSCAssert((expr), @"Unexpectedly, %s is false", #expr)
#define MPCAssertFalse(expr) NSCAssert((!(expr)), @"Unexpectedly, %s is true", #expr)

#define MPAssert NSAssert
#define MPCAssert NSCAssert

#endif
