//
//  MPFileObserver.m
//  Feather
//
//  Created by Matias Piipari on 15/07/2015.
//  Copyright (c) 2015 Matias Piipari. All rights reserved.
//

#import "MPFileObserver.h"

#import <FeatherExtensions/FeatherExtensions.h>

@interface MPFileObserver () <NSFilePresenter>
@property (readwrite) NSURL *URL;
@property (readwrite, strong) MPFileObservationChangeHandler changeHandler;
@end

@implementation MPFileObserver

- (instancetype)initWithFileURL:(NSURL *)fileURL
           subItemChangeHandler:(MPFileObservationChangeHandler)changeHandler {
    NSParameterAssert([NSThread isMainThread]);
    self = [super init];
    
    if (self) {
        _URL = fileURL;
        [NSFileCoordinator addFilePresenter:self];
        _changeHandler = changeHandler;
    }
    
    return self;
}

- (NSURL *)presentedItemURL {
    return self.URL;
}

- (NSOperationQueue *)presentedItemOperationQueue {
    return NSOperationQueue.mainQueue;
}

- (void)presentedSubitemDidChangeAtURL:(NSURL *)url {
    if (self.changeHandler)
        self.changeHandler(url);
}

@end
