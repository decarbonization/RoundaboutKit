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
    
    _pregeneratedDictionary = @{ @"test1": @{@"leaf1": @[]},
                                 @"test2": [NSNull null],
                                 @"test3": @[] };
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

- (void)testJSONDictionaryGetObjectAtKeyPath
{
    XCTAssertEqualObjects(RKJSONDictionaryGetObjectAtKeyPath(_pregeneratedDictionary, @"test1.leaf1"), @[], @"RKJSONDictionaryGetObjectAtKeyPath not indexing correctly");
    XCTAssertNil(RKJSONDictionaryGetObjectAtKeyPath(_pregeneratedDictionary, @"test2.leaf2"), @"RKJSONDictionaryGetObjectAtKeyPath not indexing correctly");
    XCTAssertEqualObjects(RKJSONDictionaryGetObjectAtKeyPath(_pregeneratedDictionary, @"test3"), @[], @"RKJSONDictionaryGetObjectAtKeyPath not indexing correctly");
}

@end
