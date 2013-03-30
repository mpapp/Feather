//
//  NSError+Manuscripts.h
//  Manuscripts
//
//  Created by Markus on 2/1/13.
//  Copyright (c) 2013 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (Manuscripts)

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
