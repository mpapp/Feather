//
//  Bindings_OSX_FrameworkTests.m
//  Bindings OSX FrameworkTests
//
//  Created by Matias Piipari on 10/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <Bindings/BindingsFramework.h>

@interface Bindings_OSX_FrameworkTests : XCTestCase

@end

@implementation Bindings_OSX_FrameworkTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testEnumParsing {
    NSError *err = nil;
    MPObjectiveCAnalyzer *analyzer = [[MPObjectiveCAnalyzer alloc] initWithBundleAtURL:
     [NSURL fileURLWithPath:@"/Users/mz2/Applications/Manuscripts.app/Contents/Frameworks/BTParse.framework"]
                                  includedHeaderPaths:@[] error:&err];
    XCTAssert(analyzer && !err, @"No error should occur when initializing the analyzer.");
    
    for (NSString *includedHeaderPath in analyzer.includedHeaderPaths) {
        [analyzer enumDeclarationsForHeaderAtPath:includedHeaderPath];
    }
}

@end
