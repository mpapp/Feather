//
//  MPJSONRepresentable.h
//  Manuscripts
//
//  Created by Matias Piipari on 08/03/2015.
//  Copyright (c) 2015 Manuscripts.app Limited. All rights reserved.
//

@protocol MPJSONRepresentable <NSObject>
- (NSString *)JSONStringRepresentation:(NSError **)error;
@end
