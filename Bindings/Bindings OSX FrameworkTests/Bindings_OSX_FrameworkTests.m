//
//  Bindings_OSX_FrameworkTests.m
//  Bindings OSX FrameworkTests
//
//  Created by Matias Piipari on 10/10/2014.
//  Copyright (c) 2014-2015 Manuscripts.app Limited. All rights reserved.
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

- (MPObjCAnalyzer *)newAnalyzer {
    NSError *err = nil;
    
    MPObjCAnalyzer *analyzer = [[MPObjCAnalyzer alloc] initWithObjectiveCHeaderText:
@"#import <Foundation/Foundation.h>\n\n\
typedef NSUInteger MPFooBarNumberA;\n\
typedef NSInteger MPFooBarNumberB;\n\
extern NSString *BDSKParserErrorNotification;\n\
const static NSUInteger MPSalmonSlapCount = 42;\n\
typedef NS_ENUM(NSUInteger, MPSalmon) {\n\
    MPFoobarUnknown = 0,\n\
    MPFoobarSomethingElse = 20\n\
};\n" additionalHeaderPaths:@[] error:&err];
    XCTAssert(analyzer && !err, @"No error should occur when initializing the analyzer.");
    
    return analyzer;
}

- (void)testTypedefParsing {
    MPObjCAnalyzer *analyzer = [self newAnalyzer];
    NSArray *typedefs = [analyzer.includedHeaderPaths mapObjectsUsingBlock:^id(NSString *headerPath, NSUInteger idx) {
        return [analyzer typeDefinitionsForHeaderAtPath:headerPath];
    }];
    
    XCTAssertTrue([[typedefs firstObject] count] == 2,
                  @"Two type definitions should have been parsed.");
    
    BOOL namesMatch = [[[typedefs firstObject] valueForKey:@"name"] isEqualToArray:@[@"MPFooBarNumberA", @"MPFooBarNumberB"]];
    XCTAssertTrue(namesMatch,
                  @"Typedef names match expectation (%@).",
                  [[typedefs firstObject] valueForKey:@"name"]);
    
    BOOL backingTypesMatch = [[[typedefs firstObject] valueForKey:@"backingType"] isEqualToArray:@[@"NSUInteger", @"NSInteger"]];
    XCTAssertTrue(backingTypesMatch,
                  @"Typedef backing types match expectation (%@).",
                  [[typedefs firstObject] valueForKey:@"backingType"]);
}

- (void)testEnumParsing {
    MPObjCAnalyzer *analyzer = [self newAnalyzer];
    NSArray *enums = [analyzer.includedHeaderPaths mapObjectsUsingBlock:^id(NSString *headerPath, NSUInteger idx) {
        return [analyzer enumDeclarationsForHeaderAtPath:headerPath];
    }];
    
    XCTAssertTrue(enums.count == 1, @"One translation unit should have been analyzed (%lu)", enums.count);
    XCTAssertTrue([[[enums.firstObject firstObject] enumConstants] count] == 2, @"There should be two values (%lu)", [[[enums.firstObject firstObject] enumConstants] count]);
    XCTAssertTrue([[enums.firstObject firstObject] isKindOfClass:MPObjCEnumDeclaration.class], @"Object should be an MPObjCEnumDeclaration");
}

- (void)testConstantParsing {
    MPObjCAnalyzer *analyzer = [self newAnalyzer];
    NSArray *consts = [analyzer.includedHeaderPaths mapObjectsUsingBlock:^id(NSString *headerPath, NSUInteger idx)
    {
        return [analyzer constantDeclarationsForHeaderAtPath:headerPath];
    }];
    
    NSArray *flattenedConsts = [consts valueForKeyPath:@"@unionOfArrays.self"];
    XCTAssertTrue(flattenedConsts.count == 2, @"Two constants should have been parsed (%lu).", flattenedConsts.count);
    
    MPObjCConstantDeclaration *constStrDec = [flattenedConsts firstObject];
    XCTAssertTrue([constStrDec.name isEqualToString:@"BDSKParserErrorNotification"],
                  @"Name should match expectation (%@)", constStrDec.name);
    XCTAssertTrue(!constStrDec.value, @"No value is known (extern: %hhd)", constStrDec.isExtern);
    XCTAssertTrue(!constStrDec.isStatic, @"Constant should not be static");
    XCTAssertTrue(!constStrDec.isConst, @"Constant should not be const");
    XCTAssertTrue(constStrDec.isExtern, @"Constant should be extern");
    
    MPObjCConstantDeclaration *constNumberDec = [flattenedConsts lastObject];
    XCTAssertTrue([constNumberDec.name isEqualToString:@"MPSalmonSlapCount"], @"Name should match expectation (%@)", constNumberDec.name);
    XCTAssertTrue([constNumberDec.value isEqualToNumber:@(42)], @"Value should match expectation (%@)", constNumberDec.value);
    XCTAssertTrue(constNumberDec.isStatic, @"Constant should be static");
    XCTAssertTrue(constNumberDec.isConst, @"Constant should be const");
    XCTAssertTrue(!constNumberDec.isExtern, @"Constant should not be extern");
}

- (void)testProtocolDeclarationParsing {
    NSError *err = nil;
    MPObjCAnalyzer *analyzer
    = [[MPObjCAnalyzer alloc] initWithObjectiveCHeaderText:
@"@protocol MPFooProtocol <NSObject>\n\
\n\
@property (readwrite, copy, getter=tehSalmon, setter=setSalmonsToSlap) NSArray *schoolOfSalmon;\n\
- (instancetype)initWithBundleAtURL:(NSURL *)url additionalHeaderPaths:(NSArray *)includedHeaders error:(NSError **)error;\n\
+ (MPObjCClassDeclaration *)classWithName:(NSString *)name;\n\
- (id)justSomeObject;\n\
\n@end\n\
@protocol MPBarProtocol <MPFooProtocol>\n\
@end\n\n\
@protocol MPBazProtocol <MPFooProtocol, MPBarProtocol>\n\
@end\n" additionalHeaderPaths:@[] error:&err];
    XCTAssert(analyzer && !err,
              @"No error should occur when initializing the analyzer.");
    XCTAssert(analyzer.includedHeaderPaths.count == 1, @"There should be a single included header (%lu)",
              analyzer.includedHeaderPaths.count);
    
    NSArray *protocols = [analyzer.includedHeaderPaths mapObjectsUsingBlock:^id(NSString *headerPath, NSUInteger idx)
    {
        return [analyzer protocolDeclarationsForHeaderAtPath:headerPath];
    }];
    
    XCTAssertTrue([protocols.firstObject count] == 3, @
                  "There should be three protocols (%lu).", [protocols.firstObject count]);
    
    XCTAssertTrue([[[protocols.firstObject objectAtIndex:0] name] isEqualToString:@"MPFooProtocol"]);
    XCTAssertTrue([[[protocols.firstObject objectAtIndex:0] conformedProtocols] containsObject:@"NSObject"]);
    XCTAssertTrue([[[protocols.firstObject objectAtIndex:0] conformedProtocols] count] == 1);
    XCTAssertTrue([[[protocols.firstObject objectAtIndex:0] instanceMethodDeclarations] count] == 2);
    XCTAssertTrue([[[protocols.firstObject objectAtIndex:0] classMethodDeclarations] count] == 1);
    XCTAssertTrue([[(MPObjCClassMethodDeclaration *)[[[protocols.firstObject objectAtIndex:0] classMethodDeclarations] firstObject] selector] isEqualToString:@"classWithName:"]);
    
    XCTAssertTrue([[[protocols.firstObject objectAtIndex:1] name] isEqualToString:@"MPBarProtocol"]);
    XCTAssertTrue([[[protocols.firstObject objectAtIndex:1] conformedProtocols] containsObject:@"MPFooProtocol"]);
    XCTAssertTrue([[[protocols.firstObject objectAtIndex:2] name] isEqualToString:@"MPBazProtocol"]);
}

- (void)testClassDeclarationParsing {
    NSError *err = nil;
    MPObjCAnalyzer *analyzer
        = [[MPObjCAnalyzer alloc] initWithObjectiveCHeaderText:@"@interface MPFoo : NSObject <X,Y,Z>\n\
@property (readwrite, copy, getter=tehSalmon, setter=setSalmonsToSlap) NSArray *schoolOfSalmon;\n\
- (instancetype)initWithBundleAtURL:(NSURL *)url additionalHeaderPaths:(NSArray *)includedHeaders error:(NSError **)error;\n\
+ (MPObjCClassDeclaration *)classWithName:(NSString *)name;\n\
- (id)justSomeObject;\n\
\n@end\n" additionalHeaderPaths:@[] error:&err];
    XCTAssert(analyzer && !err, @"No error should occur when initializing the analyzer.");
    XCTAssert(analyzer.includedHeaderPaths.count == 1, @"There should be a single included header (%lu)", analyzer.includedHeaderPaths.count);
    
    NSArray *classes = [analyzer classDeclarationsForHeaderAtPath:analyzer.includedHeaderPaths.firstObject];
    XCTAssertTrue(classes.count == 1, @"A single class was parsed.");
    MPObjCClassDeclaration *classDec = classes.firstObject;
    
    XCTAssertTrue([classDec.name isEqualToString:@"MPFoo"], @"Class name should match expectation (%@)", classDec.name);
    XCTAssertTrue([classDec.superClassName isEqualToString:@"NSObject"], @"Superclass name should match expectation (%@)", classDec.superClassName);
    XCTAssertTrue(classDec.conformedProtocols.count == 3, @"The class should conform to three classes.");
    
    BOOL protocolNamesMatchExpectation = [classDec.conformedProtocols isEqualToArray:@[@"X",@"Y",@"Z"]];
    XCTAssertTrue(protocolNamesMatchExpectation,
                  @"Protocol names should match expectation (%@)", classDec.conformedProtocols);
    
    XCTAssertTrue(classDec.propertyDeclarations.count == 1,
                  @"Class should have one property declaration (%lu).", classDec.propertyDeclarations.count);
    MPObjCPropertyDeclaration *propDec = [classDec.propertyDeclarations firstObject];
    XCTAssertTrue([propDec.name isEqualToString:@"schoolOfSalmon"],
                  @"Property name should match expectation (%@)", propDec.name);
    XCTAssertTrue([propDec.type isEqualToString:@"NSArray"] ,
                  @"Property type should match expectation (%@)", propDec.type);
    XCTAssertTrue(propDec.isObjectType, @"Property should be object-typed");
    XCTAssertTrue([propDec.ownershipAttribute isEqualToString:@"copy"],
                  @"Property ownership attribute should match expectation (%@)", propDec.ownershipAttribute);
    XCTAssertTrue([propDec.setterName isEqualToString:@"setSalmonsToSlap"],
                  @"Custom setter was correctly detected (%@).", propDec.setterName);
    XCTAssertTrue([propDec.getterName isEqualToString:@"tehSalmon"],
                  @"Custom getter was correctly detected (%@).", propDec.getterName);
    
    XCTAssertTrue(classDec.instanceMethodDeclarations.count == 2,
                  @"There should be a single instance method (%lu)", classDec.instanceMethodDeclarations.count);
    
    MPObjCInstanceMethodDeclaration *im1 = classDec.instanceMethodDeclarations[0];
    XCTAssertTrue([im1.selector isEqualToString:@"initWithBundleAtURL:additionalHeaderPaths:error:"],
                  @"Unexpected selector: %@", im1.selector);
    XCTAssertTrue([im1.returnType isEqualToString:@"instancetype"], @"Unexpected return type: %@", im1.returnType);
    
    MPObjCInstanceMethodDeclaration *im2 = classDec.instanceMethodDeclarations[1];
    XCTAssertTrue([im2.selector isEqualToString:@"justSomeObject"]);
    XCTAssertTrue([im2.returnType isEqualToString:@"id"], @"Unexpected return type: %@", im2.returnType);
    
    XCTAssertTrue(classDec.classMethodDeclarations.count == 1,
                  @"There should be a single class method (%lu)", classDec.classMethodDeclarations.count);
    
    MPObjCClassMethodDeclaration *cm1 = [[classDec classMethodDeclarations] firstObject];
    XCTAssertTrue([cm1.returnType isEqualToString:@"MPObjCClassDeclaration"]);
    XCTAssertTrue([cm1.selector isEqualToString:@"classWithName:"]);
}

- (void)testObjCToCSharpTransformation {
    MPObjCAnalyzer *analyzer = [self newAnalyzer];
    MPObjCTranslator *translator = [MPObjCToCSharpTranslator new];
    
    NSMutableArray *enumDeclarations = [NSMutableArray new];
    NSMutableArray *classDeclarations = [NSMutableArray new];
    [analyzer enumerateTranslationUnits:^(NSString *path, CKTranslationUnit *unit) {
        MPObjCTranslationUnit *tUnit = [analyzer analyzedTranslationUnitForClangKitTranslationUnit:unit atPath:path];
        
        [enumDeclarations addObject:[translator translatedEnumDeclarationsForTranslationUnit:tUnit]];
        [classDeclarations addObject:[translator]]
    }];
    
    BOOL enumDeclarationsMatchExpectation = [enumDeclarations.firstObject isEqualToString:@"public enum MPSalmon\n{\n        MPFoobarUnknown = 0,\n        MPFoobarSomethingElse = 20\n}\n"];
    
    XCTAssertTrue(enumDeclarationsMatchExpectation, @"Unepected enum declarations: %@", enumDeclarations.firstObject);
    
}

@end
