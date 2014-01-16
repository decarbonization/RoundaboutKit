//
//  RKRequestParametersTests.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/19/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RKRequestParameters.h"

@interface RKRequestParametersTests : XCTestCase

@end

@implementation RKRequestParametersTests

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

#pragma mark - Modes

- (void)testThrowsMode
{
    RKRequestParameters *test = [[RKRequestParameters alloc] initWithNilHandlingMode:RKRequestParametersNilHandlingModeThrow];
    XCTAssertThrows([test setObject:nil forKey:@"key"], @"should throw");
    XCTAssertNil(test[@"key"], @"should be nil");
}

- (void)testIgnoreMode
{
    RKRequestParameters *test = [[RKRequestParameters alloc] initWithNilHandlingMode:RKRequestParametersNilHandlingModeIgnore];
    XCTAssertNoThrow([test setObject:nil forKey:@"key"], @"should not throw");
    XCTAssertNil(test[@"key"], @"should be nil");
}

- (void)testEmptyStringMode
{
    RKRequestParameters *test = [[RKRequestParameters alloc] initWithNilHandlingMode:RKRequestParametersNilHandlingModeSubstituteEmptyString];
    XCTAssertNoThrow([test setObject:nil forKey:@"key"], @"should not throw");
    XCTAssertEqualObjects(test[@"key"], @"", @"should be empty string");
}

- (void)testNSNullMode
{
    RKRequestParameters *test = [[RKRequestParameters alloc] initWithNilHandlingMode:RKRequestParametersNilHandlingModeSubstituteNSNull];
    XCTAssertNoThrow([test setObject:nil forKey:@"key"], @"should not throw");
    XCTAssertEqualObjects(test[@"key"], [NSNull null], @"should be NSNull");
}

#pragma mark - Conversions

- (void)testDictionaryRepresentation
{
    RKRequestParameters *test = [[RKRequestParameters alloc] initWithNilHandlingMode:RKRequestParametersNilHandlingModeThrow];
    test[@"one"] = @1;
    test[@"two"] = @2;
    test[@"three"] = @3;
    XCTAssertEqualObjects([test dictionaryRepresentation], (@{@"one": @1, @"two": @2, @"three": @3}), @"unexpected dictionary representation");
}

@end
