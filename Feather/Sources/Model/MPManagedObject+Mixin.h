//
//  MPDeliverable.h
//  Manuscripts
//
//  Created by Matias Piipari on 22/12/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPManagedObject.h"

typedef BOOL (^MPAdoptedProtocolPatternBlock)(NSString *adoptedProtocolName);

@interface MPManagedObject (MPManagedObjectMixIn)

+ (void)implementProtocol:(Protocol *)protocol
          overloadMethods:(BOOL)overloadMethods;

+ (void)implementProtocol:(Protocol *)protocol
     andProtocolsMatching:(MPAdoptedProtocolPatternBlock)patternBlock
         overloadMethods:(BOOL)overloadMethods;

@end