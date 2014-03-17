//
//  RKPreludeCollectionTests.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 3/17/14.
//  Copyright (c) 2014 Roundabout Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface RKPreludeCollectionTests : XCTestCase

@end

@implementation RKPreludeCollectionTests {
    NSArray *_pregeneratedArray;
}

- (void)setUp
{
    [super setUp];
    
    _pregeneratedArray = @[ @"1", @"2", @"3", @"4", @"5" ];
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark - • Generation

- (void)testCollectionGeneration
{
    NSArray *generatedArray = RKCollectionGenerateArray(5, ^id(NSUInteger index) {
        return [NSString stringWithFormat:@"%ld", index + 1];
    });
    XCTAssertEqualObjects(generatedArray, _pregeneratedArray, @"RKCollectionGenerateArray returned incorrect value");
}

#pragma mark - • Mapping

- (void)testCollectionMapToArray
{
    NSArray *mappedArray = RKCollectionMapToArray(_pregeneratedArray, ^id(NSString *value) {
        return [value stringByAppendingString:@"0"];
    });
    NSArray *expectedArray = @[ @"10", @"20", @"30", @"40", @"50" ];
    XCTAssertEqualObjects(mappedArray, expectedArray, @"RKCollectionMapToArray returned incorrect value");
}

- (void)testCollectionMapToMutableArray
{
    NSMutableArray *mappedArray = RKCollectionMapToMutableArray(_pregeneratedArray, ^id(NSString *value) {
        return [value stringByAppendingString:@"0"];
    });
    NSArray *expectedArray = @[ @"10", @"20", @"30", @"40", @"50" ];
    XCTAssertEqualObjects(mappedArray, expectedArray, @"RKCollectionMapToMutableArray returned incorrect value");
    
    XCTAssertNoThrow([mappedArray addObject:@"60"], @"RKCollectionMapToMutableArray returned non-mutable array");
}

- (void)testCollectionMapToOrderedSet
{
    NSOrderedSet *mappedOrderedSet = RKCollectionMapToOrderedSet(_pregeneratedArray, ^id(NSString *value) {
        return [value stringByAppendingString:@"0"];
    });
    NSOrderedSet *expectedOrderedSet = [NSOrderedSet orderedSetWithObjects:@"10", @"20", @"30", @"40", @"50", nil];
    XCTAssertEqualObjects(mappedOrderedSet, expectedOrderedSet, @"RKCollectionMapToOrderedSet returned incorrect value");
}

#pragma mark - • Filtering

- (void)testFilterToArray
{
    NSArray *filteredArray = RKCollectionFilterToArray(_pregeneratedArray, ^BOOL(NSString *value) {
        return ([value integerValue] % 2 == 0);
    });
    NSArray *expectedArray = @[ @"2", @"4" ];
    XCTAssertEqualObjects(filteredArray, expectedArray, @"RKCollectionFilterToArray returned incorrect value");
}

#pragma mark - • Reducing

- (void)testCollectionReduce
{
    NSString *result = RKCollectionReduce(_pregeneratedArray, ^id(NSString *accumulator, NSString *value) {
        return [accumulator stringByAppendingString:value];
    });
    
    XCTAssertEqualObjects(result, @"12345", @"RKCollectionReduce returned incorrect value");
}

#pragma mark - • Matching

- (void)testDoesAnyValueMatch
{
    BOOL doesAnyValueMatch = RKCollectionDoesAnyValueMatch(_pregeneratedArray, ^BOOL(NSString *value) {
        return [value isEqualToString:@"3"];
    });
    XCTAssertTrue(doesAnyValueMatch, @"RKCollectionDoesAnyValueMatch returned incorrect value");
}

- (void)testDoAllValuesMatch
{
    BOOL doAllValuesMatch = RKCollectionDoAllValuesMatch(_pregeneratedArray, ^BOOL(NSString *value) {
        return [value integerValue] != 0;
    });
    XCTAssertTrue(doAllValuesMatch, @"RKCollectionDoAllValuesMatch returned incorrect value");
}

- (void)testFindFirstMatch
{
    NSString *firstMatch = RKCollectionFindFirstMatch(_pregeneratedArray, ^BOOL(NSString *value) {
        return [value isEqualToString:@"3"];
    });
    
    XCTAssertEqualObjects(firstMatch, @"3", @"RKCollectionFindFirstMatch returned incorrect value");
}

@end
