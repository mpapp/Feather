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
    XCTAssertTrue(flattenedConsts.count == 2, @"Two constants should have been parsed (%lu).", flattenedConsts.count);
    
    MPObjectiveCConstantDeclaration *constStrDec = [flattenedConsts firstObject];
    XCTAssertTrue([constStrDec.name isEqualToString:@"BDSKParserErrorNotification"],
                  @"Name should match expectation (%@)", constStrDec.name);
    XCTAssertTrue(!constStrDec.value, @"No value is known (extern: %hhd)", constStrDec.isExtern);
    XCTAssertTrue(!constStrDec.isStatic, @"Constant should not be static");
    XCTAssertTrue(!constStrDec.isConst, @"Constant should not be const");
    XCTAssertTrue(constStrDec.isExtern, @"Constant should be extern");
    
    MPObjectiveCConstantDeclaration *constNumberDec = [flattenedConsts lastObject];
    XCTAssertTrue([constNumberDec.name isEqualToString:@"MPSlappedSalmon"], @"Name should match expectation (%@)", constNumberDec.name);
    XCTAssertTrue([constNumberDec.value isEqualToNumber:@(42)], @"Value should match expectation (%@)", constNumberDec.value);
    XCTAssertTrue(constNumberDec.isStatic, @"Constant should be static");
    XCTAssertTrue(constNumberDec.isConst, @"Constant should be const");
    XCTAssertTrue(!constNumberDec.isExtern, @"Constant should not be extern");
}

- (void)testClassDeclarationParsing {
    NSError *err = nil;
    MPObjectiveCAnalyzer *analyzer
        = [[MPObjectiveCAnalyzer alloc] initWithObjectiveCHeaderText:@"@interface MPFoo : NSObject <X,Y,Z>\n@property (readwrite, copy) NSArray *schoolOfSalmon;\n @end\n" additionalHeaderPaths:@[] error:&err];
    XCTAssert(analyzer && !err, @"No error should occur when initializing the analyzer.");
    XCTAssert(analyzer.includedHeaderPaths.count == 1, @"There should be a single included header (%lu)", analyzer.includedHeaderPaths.count);
    
    NSArray *classes = [analyzer classDeclarationsForHeaderAtPath:analyzer.includedHeaderPaths.firstObject];
    XCTAssertTrue(classes.count == 1, @"A single class was parsed.");
    MPObjectiveCClassDeclaration *classDec = classes.firstObject;
    
    XCTAssertTrue([classDec.name isEqualToString:@"MPFoo"], @"Class name should match expectation (%@)", classDec.name);
    XCTAssertTrue([classDec.superClassName isEqualToString:@"NSObject"], @"Superclass name should match expectation (%@)", classDec.superClassName);
    XCTAssertTrue(classDec.conformedProtocols.count == 3, @"The class should conform to three classes.");
    
    BOOL protocolNamesMatchExpectation = [classDec.conformedProtocols isEqualToArray:@[@"X",@"Y",@"Z"]];
    XCTAssertTrue(protocolNamesMatchExpectation, @"Protocol names should match expectation (%@)", classDec.conformedProtocols);
    
    XCTAssertTrue(classDec.propertyDeclarations.count == 1, @"Class should have one property declaration (%lu).", classDec.propertyDeclarations.count);
    MPObjectiveCPropertyDeclaration *propDec = [classDec.propertyDeclarations firstObject];
    XCTAssertTrue([propDec.name isEqualToString:@"schoolOfSalmon"], @"Property name should match expectation (%@)", propDec.name);
    XCTAssertTrue([propDec.type isEqualToString:@"NSArray"] , @"Property type should match expectation (%@)", propDec.type);
    XCTAssertTrue(propDec.isObjectType, @"Property should be object-typed");
    XCTAssertTrue([propDec.ownershipAttribute isEqualToString:@"copy"], @"Property ownership attribute should match expectation (%@)", propDec.ownershipAttribute);
    
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
