//
//  RKCorePostProcessorsTests.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 1/28/14.
//  Copyright (c) 2014 Roundabout Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface RKCorePostProcessorsTests : XCTestCase

@end

@implementation RKCorePostProcessorsTests

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

#pragma mark -

- (void)testJSONPostProcessor
{
    RKJSONPostProcessor *postProcessor = [RKJSONPostProcessor sharedPostProcessor];
    NSError *error = nil;
    id value = nil;
    
    NSData *goodInput = [@"[1, 2, 3]" dataUsingEncoding:NSUTF8StringEncoding];
    value = [postProcessor processValue:goodInput error:&error withContext:nil];
    XCTAssertNil(error, @"unexpected error");
    XCTAssertNotNil(value, @"expected value");
    XCTAssertEqualObjects((@[@1, @2, @3]), value, @"unexpected output");
    
    
    error = nil;
    value = nil;
    
    NSData *badInput = [@"[1, 2, 3," dataUsingEncoding:NSUTF8StringEncoding];
    value = [postProcessor processValue:badInput error:&error withContext:nil];
    XCTAssertNotNil(error, @"expected error");
    XCTAssertNil(value, @"unexpected value");
}

- (void)testPropertyListPostProcessor
{
    RKPropertyListPostProcessor *postProcessor = [RKPropertyListPostProcessor sharedPostProcessor];
    NSError *error = nil;
    id value = nil;
    
    NSData *goodInput = [@"(1, 2, 3)" dataUsingEncoding:NSUTF8StringEncoding];
    value = [postProcessor processValue:goodInput error:&error withContext:nil];
    XCTAssertNil(error, @"unexpected error");
    XCTAssertNotNil(value, @"expected value");
    XCTAssertEqualObjects((@[@"1", @"2", @"3"]), value, @"unexpected output");
    
    
    error = nil;
    value = nil;
    
    NSData *badInput = [@"(1, 2, 3," dataUsingEncoding:NSUTF8StringEncoding];
    value = [postProcessor processValue:badInput error:&error withContext:nil];
    XCTAssertNotNil(error, @"expected error");
    XCTAssertNil(value, @"unexpected value");
}

- (void)testImagePostProcessor
{
    NSError *error = nil;
    id image = nil;
    
    NSURL *goodDataLocation = [[NSBundle bundleForClass:[self class]] URLForImageResource:@"RKPostProcessorTestImage"];
    NSData *goodData = [NSData dataWithContentsOfURL:goodDataLocation];
    
    RKImagePostProcessor *postProcessor = [RKImagePostProcessor sharedPostProcessor];
    
    image = [postProcessor processValue:goodData error:&error withContext:nil];
    XCTAssertNil(error, @"unexpected error");
    XCTAssertNotNil(image, @"expected value");
    
    
    error = nil;
    image = nil;
    
    NSData *badData = [@"this is garbage" dataUsingEncoding:NSUTF8StringEncoding];
    image = [postProcessor processValue:badData error:&error withContext:nil];
    XCTAssertNotNil(error, @"expected error");
    XCTAssertNil(image, @"unexpected value");
}

@end
