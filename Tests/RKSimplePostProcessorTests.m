//
//  RKPostProcessorTests.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/6/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface RKSimplePostProcessorTests : XCTestCase

@end

@implementation RKSimplePostProcessorTests

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

#pragma mark - Simple Post Processor Tests

- (void)testValue
{
    RKSimplePostProcessor *valueProcessor = [[RKSimplePostProcessor alloc] initWithBlock:^RKPossibility *(RKPossibility *maybeData, id context) {
        XCTAssertNotNil(context, @"context missing");
        XCTAssertEqual(maybeData.state, kRKPossibilityStateValue, @"wrong possibility state");
        
        return [maybeData refineValue:^RKPossibility *(NSString *value) {
            return [[RKPossibility alloc] initWithValue:[value stringByAppendingString:@"foo"]];
        }];
    }];
    
    NSError *error = nil;
    id value = [valueProcessor processValue:@"test" error:&error withContext:@"context"];
    
    XCTAssertNil(error, @"unexpected error");
    XCTAssertNotNil(value, @"missing value");
    XCTAssertEqualObjects(value, @"testfoo", @"wrong value");
}

- (void)testError
{
    RKSimplePostProcessor *errorProcessor = [[RKSimplePostProcessor alloc] initWithBlock:^RKPossibility *(RKPossibility *maybeData, id context) {
        XCTAssertNotNil(context, @"context missing");
        XCTAssertEqual(maybeData.state, kRKPossibilityStateValue, @"wrong possibility state");
        
        return [maybeData refineValue:^RKPossibility *(NSString *value) {
            return [[RKPossibility alloc] initWithError:[NSError errorWithDomain:@"SillyErrorDomain"
                                                                            code:'dumb'
                                                                        userInfo:@{NSLocalizedDescriptionKey: @"It worked!"}]];
        }];
    }];
    
    NSError *error = nil;
    id value = [errorProcessor processValue:@"test" error:&error withContext:@"context"];
    
    XCTAssertNotNil(error, @"missing error");
    XCTAssertNil(value, @"unexpected value");
}

@end
