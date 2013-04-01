//
//  NSError+MPExtensions.h
//  Feather
//
//  Created by Markus on 2/1/13.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (Feather)

+ (NSError *)errorWithDomain:(NSString *)domain code:(NSInteger)code
                 description:(NSString *)description;

+ (NSError *)errorWithDomain:(NSString *)domain
                        code:(NSInteger)code
                 description:(NSString *)description
                      reason:(NSString *)reason;

+ (NSError *)errorWithDomain:(NSString *)domain
                        code:(NSInteger)code
                 description:(NSString *)description
             underlyingError:(NSError *)originalError;

@end
