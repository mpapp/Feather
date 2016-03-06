//
//  NSError+MPExtensions.h
//  Feather
//
//  Created by Markus on 2/1/13.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

@import Foundation;

@interface NSError (Feather)

+ (nonnull NSError *)errorWithDomain:(nonnull NSString *)domain
                                code:(NSInteger)code
                         description:(nonnull NSString *)description;

+ (nonnull NSError *)errorWithDomain:(nonnull NSString *)domain
                                code:(NSInteger)code
                         description:(nonnull NSString *)description
                              reason:(nonnull NSString *)reason;

+ (nonnull NSError *)errorWithDomain:(nonnull NSString *)domain
                                code:(NSInteger)code
                         description:(nonnull NSString *)description
                     underlyingError:(nonnull NSError *)originalError;

- (nonnull NSError *)errorByMarkingAsShouldPresent;

- (BOOL)shouldPresent;

@end
