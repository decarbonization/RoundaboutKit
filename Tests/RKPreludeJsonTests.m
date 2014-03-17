//
//  RKPreludeJsonTests.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 3/17/14.
//  Copyright (c) 2014 Roundabout Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface RKPreludeJsonTests : XCTestCase

@end

@implementation RKPreludeJsonTests {
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

- (void)testFilterOutNSNull
{
    XCTAssertNotNil(RKFilterOutNSNull(@"test"), @"RKFilterOutNSNull returned inappropriate nil");
    XCTAssertNil(RKFilterOutNSNull([NSNull null]), @"RKFilterOutNSNull didn't filter out NSNull");
}

- (void)testTraversalExceptions
{
    XCTAssertThrows(RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.{NSDictionary"), @"Should throw for open curly brace");
    XCTAssertThrows(RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.NSDictionary}"), @"Should throw for unexpected closing curly brace");
    XCTAssertThrows(RKTraverseJson(_pregeneratedDictionary, @"{NSDictionary}"), @"Should throw for assertion at beginning");
    XCTAssertThrows(RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.{NSNotRealClass}"), @"Should throw for missing class");
    XCTAssertThrows(RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.arraySubLeaf.@sum"), @"Should throw for key path operator");
}

- (void)testSimpleTraversal
{
    XCTAssertEqualObjects(RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.arraySubLeaf"), @[], @"Multi-level paths broken");
    XCTAssertEqualObjects(RKTraverseJson(_pregeneratedDictionary, @"arrayLeaf"), (@[@"2", @"3", @"5"]), @"Single level paths broken");
}

- (void)testNullBehavior
{
    XCTAssertNil(RKTraverseJson(_pregeneratedDictionary, @"nullLeaf.nonExistentLeaf1"), @"NSNull not being converted to nil correctly.");
    XCTAssertNil(RKTraverseJson(_pregeneratedDictionary, @"nullLeaf.nonExistentLeaf1.nonExistentLeaf2"), @"Traversing on nil leaf broken.");
}

- (void)testSingleLevelTypeSafety
{
    id successResult = RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.{NSDictionary}");
    XCTAssertNotNil(successResult, @"Single level type assertion failed.");
    XCTAssertTrue([successResult isKindOfClass:[NSDictionary class]], @"Single level type assertion yielded wrong type");
    
    id failureResult = RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.{NSString}");
    XCTAssertNil(failureResult, @"Single level type assertion yielded inapproriate value");
}

- (void)testMultiLevelTypeSafety
{
    id successResult = RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.{NSDictionary}.arraySubLeaf.{NSArray}");
    XCTAssertNotNil(successResult, @"Multi-level type assertion failed.");
    XCTAssertTrue([successResult isKindOfClass:[NSArray class]], @"Multi-level type assertion yielded wrong type");
    
    id failureResult = RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.{NSDictionary}.arraySubLeaf.{NSSet}");
    XCTAssertNil(failureResult, @"Multi-level type assertion yielded inappropriate value on last leaf");
    
    id cascadingFailureResult = RKTraverseJson(_pregeneratedDictionary, @"dictionaryLeaf.{NSSet}.arraySubLeaf.{NSArray}");
    XCTAssertNil(cascadingFailureResult, @"Multi-level type assertion yielded inappropriate value on first leaf for cascading failure.");
}

- (void)testPredicates
{
    NSArray *result = RKTraverseJson(_pregeneratedDictionary, @"arrayLeaf.{if SELF[SIZE] == 3}");
    XCTAssertNotNil(result, @"Truthy array predicate failed");
    XCTAssertEqual(result.count, (NSUInteger)3, @"Wrong count");
}

@end
