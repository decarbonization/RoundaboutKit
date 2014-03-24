//
//  RKPreludeJsonTests.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 3/17/14.
//  Copyright (c) 2014 Roundabout Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface RKJsonTests : XCTestCase

@end

@implementation RKJsonTests {
    NSDictionary *_pregeneratedDictionary;
}

- (void)setUp
{
    [super setUp];
    
    _pregeneratedDictionary = @{ @"dictionaryLeaf": @{@"arraySubLeaf": @[]},
                                 @"nullLeaf": [NSNull null],
                                 @"arrayLeaf": @[@"2", @"3", @"5"] };
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark -

- (void)testTraversalExceptions
{
    XCTAssertThrows(RKTraverseJson(_pregeneratedDictionary, @"(NSDictionarydictionaryLeaf", NULL), @"Should throw for open parenthesis");
    XCTAssertThrows(RKTraverseJson(_pregeneratedDictionary, @"NSDictionary)dictionaryLeaf", NULL), @"Should throw for unexpected closing parenthesis");
    XCTAssertThrows(RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.{NSDictionary}", NULL), @"Should throw for malformed assertion");
    XCTAssertThrows(RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.{if SELF[SIZE] == 3", NULL), @"Should throw for open curly bracket");
    XCTAssertThrows(RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.if SELF[SIZE] == 3}", NULL), @"Should throw for unexpected closing curly bracket");
    XCTAssertThrows(RKTraverseJson(_pregeneratedDictionary, @"{if SELF[SIZE] == 3}", NULL), @"Should throw for conditional assertion at beginning");
    XCTAssertThrows(RKTraverseJson(_pregeneratedDictionary, @"(NSNotRealClass)dictionaryLeaf", NULL), @"Should throw for missing class");
    XCTAssertThrows(RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.arraySubLeaf.@sum", NULL), @"Should throw for key path operator");
}

- (void)testSimpleTraversal
{
    NSError *error = nil;
    
    XCTAssertEqualObjects(RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.arraySubLeaf", &error), @[], @"Multi-level paths broken");
    XCTAssertNil(error, @"unexpected error");
    
    XCTAssertEqualObjects(RKTraverseJson(_pregeneratedDictionary, @"arrayLeaf", &error), (@[@"2", @"3", @"5"]), @"Single level paths broken");
    XCTAssertNil(error, @"unexpected error");
}

- (void)testNullBehavior
{
    NSError *error = nil;
    
    XCTAssertNil(RKTraverseJson(_pregeneratedDictionary, @"nullLeaf.nonExistentLeaf1", &error), @"NSNull not being converted to nil correctly.");
    XCTAssertNotNil(error, @"Missing error");
    XCTAssertEqual(error.code, kRKJsonTraversingErrorCodeNullEncountered, @"Wrong error code");
    
    XCTAssertNil(RKTraverseJson(_pregeneratedDictionary, @"nullLeaf.nonExistentLeaf1.nonExistentLeaf2", &error), @"Traversing on nil leaf broken.");
    XCTAssertNotNil(error, @"Missing error");
    XCTAssertEqual(error.code, kRKJsonTraversingErrorCodeNullEncountered, @"Wrong error code");
}

- (void)testIntentionalNullBehavior
{
    NSError *error = nil;
    id value = nil;
    
    value = RKTraverseJson(_pregeneratedDictionary, @"nullLeaf?.nonExistentLeaf1", &error);
    XCTAssertNil(error, @"unexpected error");
    XCTAssertNil(value, @"unexpected value");
    
    value = RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.nonExistentLeaf1?", &error);
    XCTAssertNil(error, @"unexpected error");
    XCTAssertNil(value, @"unexpected value");
}

- (void)testSingleLevelTypeSafety
{
    NSError *error = nil;
    
    id successResult = RKTraverseJson(_pregeneratedDictionary, @"(NSDictionary)dictionaryLeaf", &error);
    XCTAssertNotNil(successResult, @"Single level type assertion failed.");
    XCTAssertTrue([successResult isKindOfClass:[NSDictionary class]], @"Single level type assertion yielded wrong type");
    XCTAssertNil(error, @"unexpected error");
    
    id failureResult = RKTraverseJson(_pregeneratedDictionary, @"(NSString)dictionaryLeaf", &error);
    XCTAssertNil(failureResult, @"Single level type assertion yielded inapproriate value");
    XCTAssertNotNil(error, @"Missing error");
    XCTAssertEqual(error.code, kRKJsonTraversingErrorCodeTypeUnsatisfied, @"Wrong error code");
}

- (void)testMultiLevelTypeSafety
{
    NSError *error = nil;
    
    id successResult = RKTraverseJson(_pregeneratedDictionary, @"(NSDictionary)dictionaryLeaf.(NSArray)arraySubLeaf", &error);
    XCTAssertNotNil(successResult, @"Multi-level type assertion failed.");
    XCTAssertTrue([successResult isKindOfClass:[NSArray class]], @"Multi-level type assertion yielded wrong type");
    XCTAssertNil(error, @"Unexpected error");
    
    id failureResult = RKTraverseJson(_pregeneratedDictionary, @"(NSDictionary)dictionaryLeaf.(NSSet)arraySubLeaf", &error);
    XCTAssertNil(failureResult, @"Multi-level type assertion yielded inappropriate value on last leaf");
    XCTAssertNotNil(error, @"Expected error");
    XCTAssertEqual(error.code, kRKJsonTraversingErrorCodeTypeUnsatisfied, @"Wrong error code");
    
    id cascadingFailureResult = RKTraverseJson(_pregeneratedDictionary, @"(NSSet)dictionaryLeaf.(NSArray)arraySubLeaf", &error);
    XCTAssertNil(cascadingFailureResult, @"Multi-level type assertion yielded inappropriate value on first leaf for cascading failure.");
    XCTAssertNotNil(error, @"Expected error");
    XCTAssertEqual(error.code, kRKJsonTraversingErrorCodeTypeUnsatisfied, @"Wrong error code");
}

- (void)testPredicates
{
    NSError *error = nil;
    
    NSArray *successResult = RKTraverseJson(_pregeneratedDictionary, @"arrayLeaf.{if SELF[SIZE] == 3}", &error);
    XCTAssertNotNil(successResult, @"Truthy array predicate failed");
    XCTAssertEqual(successResult.count, (NSUInteger)3, @"Wrong count");
    XCTAssertNil(error, @"unexpected error");
    
    NSArray *failureResult = RKTraverseJson(_pregeneratedDictionary, @"arrayLeaf.{if SELF[SIZE] == 99}", &error);
    XCTAssertNil(failureResult, @"Unexpected value");
    XCTAssertNotNil(error, @"Expected error");
    XCTAssertEqual(error.code, kRKJsonTraversingErrorCodeConditionUnsatisifed, @"Wrong error code");
}

@end
