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

#import <Feather/NSArray+MPExtensions.h>

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

- (MPObjectiveCAnalyzer *)newAnalyzer {
    NSError *err = nil;
    MPObjectiveCAnalyzer *analyzer = [[MPObjectiveCAnalyzer alloc] initWithBundleAtURL:
                                      [NSURL fileURLWithPath:@"/Users/mz2/Applications/Manuscripts.app/Contents/Frameworks/BTParse.framework"]
                                                                 additionalHeaderPaths:@[] error:&err];
    XCTAssert(analyzer && !err, @"No error should occur when initializing the analyzer.");
    
    return analyzer;
}

- (void)testEnumParsing {
    MPObjectiveCAnalyzer *analyzer = [self newAnalyzer];
    NSArray *enums = [analyzer.includedHeaderPaths mapObjectsUsingBlock:^id(NSString *headerPath, NSUInteger idx) {
        return [analyzer enumDeclarationsForHeaderAtPath:headerPath];
    }];
    
    XCTAssertTrue(enums.count == 2, @"Two classes should have been analyzed (%lu)", enums.count);
    XCTAssertTrue([[[enums.firstObject firstObject] enumConstants] count] == 2, @"There should be two values");
    XCTAssertTrue([[enums.firstObject firstObject] isKindOfClass:MPObjectiveCEnumDeclaration.class], @"Object should be an MPObjectiveCEnumDeclaration");
    XCTAssertTrue([[[[enums lastObject] firstObject] enumConstants] count] == 0, @"There should be two values");
}

- (void)testConstantParsing {
    MPObjectiveCAnalyzer *analyzer = [self newAnalyzer];
    NSArray *consts = [analyzer.includedHeaderPaths mapObjectsUsingBlock:^id(NSString *headerPath, NSUInteger idx) {
        NSLog(@"%@", headerPath);
        return [analyzer constantDeclarationsForHeaderAtPath:headerPath];
    }];
    
    NSArray *flattenedConsts = [consts valueForKeyPath:@"@unionOfArrays.self"];
    XCTAssertTrue(flattenedConsts.count == 1, @"A single constant should be parsed (%lu).", consts.count);
    
    MPObjectiveCConstantDeclaration *constDec = [flattenedConsts firstObject];
    XCTAssertTrue([constDec.name isEqualToString:@"MPSlappedSalmon"], @"Name should match expectation (%@)", constDec.name);
    XCTAssertTrue([constDec.value isEqualToNumber:@(42)], @"Value should match expectation (%@)", constDec.value);
    XCTAssertTrue(constDec.isStatic, @"Constant should be static");
    XCTAssertTrue(constDec.isConst, @"Constant should be const");
    XCTAssertTrue(constDec.isExtern, @"Constant should not be extern");
}

- (void)testObjCToCSharpTransformation {
    MPObjectiveCAnalyzer *analyzer = [self newAnalyzer];
    MPObjectiveCTranslator *translator = [MPObjectiveCToCSharpTranslator new];
    
    NSMutableArray *enumDeclarations = [NSMutableArray new];
    [analyzer enumerateTranslationUnits:^(NSString *path, CKTranslationUnit *unit) {
        MPObjectiveCTranslationUnit *tUnit = [analyzer analyzedTranslationUnitForClangKitTranslationUnit:unit atPath:path];
        
        [enumDeclarations addObject:[translator translatedEnumDeclarationsForTranslationUnit:tUnit]];
    }];
    
    BOOL enumDeclarationsMatchExpectation = [enumDeclarations.firstObject isEqualToString:@"public enum MPSalmon\n{\n        MPFoobarUnknown = 0,\n        MPFoobarSomethingElse = 20\n}\n"];
    
    XCTAssertTrue(enumDeclarationsMatchExpectation, @"Unepected enum declarations: %@", enumDeclarations.firstObject);
}

@end
