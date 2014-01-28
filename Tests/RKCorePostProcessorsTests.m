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
    NSData *goodJSON = [@"[1, 2, 3]" dataUsingEncoding:NSUTF8StringEncoding];
    RKJSONPostProcessor *goodPostProcessor = [RKJSONPostProcessor new];
    
    [goodPostProcessor processInputValue:goodJSON inputError:nil context:nil];
    XCTAssertNil(goodPostProcessor.outputError, @"unexpected error");
    XCTAssertNotNil(goodPostProcessor.outputValue, @"expected value");
    XCTAssertEqualObjects((@[@1, @2, @3]), goodPostProcessor.outputValue, @"unexpected output");
    
    
    NSData *badJSON = [@"[1, 2, 3," dataUsingEncoding:NSUTF8StringEncoding];
    RKJSONPostProcessor *badPostProcessor = [RKJSONPostProcessor new];
    
    [badPostProcessor processInputValue:badJSON inputError:nil context:nil];
    XCTAssertNotNil(badPostProcessor.outputError, @"expected error");
    XCTAssertNil(badPostProcessor.outputValue, @"unexpected value");
}

- (void)testPropertyListPostProcessor
{
    NSData *goodPropertyList = [@"(1, 2, 3)" dataUsingEncoding:NSUTF8StringEncoding];
    RKPropertyListPostProcessor *goodPostProcessor = [RKPropertyListPostProcessor new];
    
    [goodPostProcessor processInputValue:goodPropertyList inputError:nil context:nil];
    XCTAssertNil(goodPostProcessor.outputError, @"unexpected error");
    XCTAssertNotNil(goodPostProcessor.outputValue, @"expected value");
    XCTAssertEqualObjects((@[@"1", @"2", @"3"]), goodPostProcessor.outputValue, @"unexpected output");
    
    
    NSData *badPropertyList = [@"(1, 2, 3," dataUsingEncoding:NSUTF8StringEncoding];
    RKPropertyListPostProcessor *badPostProcessor = [RKPropertyListPostProcessor new];
    
    [badPostProcessor processInputValue:badPropertyList inputError:nil context:nil];
    XCTAssertNotNil(badPostProcessor.outputError, @"expected error");
    XCTAssertNil(badPostProcessor.outputValue, @"unexpected value");
}

- (void)testImagePostProcessor
{
    NSURL *goodImageLocation = [[NSBundle bundleForClass:[self class]] URLForImageResource:@"RKPostProcessorTestImage"];
    NSData *goodImage = [NSData dataWithContentsOfURL:goodImageLocation];
    
    RKImagePostProcessor *goodPostProcessor = [RKImagePostProcessor new];
    
    [goodPostProcessor processInputValue:goodImage inputError:nil context:nil];
    XCTAssertNil(goodPostProcessor.outputError, @"unexpected error");
    XCTAssertNotNil(goodPostProcessor.outputValue, @"expected value");
    
    
    NSData *badPropertyList = [@"this is garbage" dataUsingEncoding:NSUTF8StringEncoding];
    RKImagePostProcessor *badPostProcessor = [RKImagePostProcessor new];
    
    [badPostProcessor processInputValue:badPropertyList inputError:nil context:nil];
    XCTAssertNotNil(badPostProcessor.outputError, @"expected error");
    XCTAssertNil(badPostProcessor.outputValue, @"unexpected value");
}

@end
