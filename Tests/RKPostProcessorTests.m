//
//  RKPostProcessorTests.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/6/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface RKPostProcessorTests : XCTestCase

@end

@implementation RKPostProcessorTests

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
    RKLegacyPostProcessor *valueProcessor = [[RKLegacyPostProcessor alloc] initWithBlock:^RKPossibility *(RKPossibility *maybeData, id context) {
        XCTAssertNotNil(context, @"context missing");
        XCTAssertEqual(maybeData.state, kRKPossibilityStateValue, @"wrong possibility state");
        
        return [maybeData refineValue:^RKPossibility *(NSString *value) {
            return [[RKPossibility alloc] initWithValue:[value stringByAppendingString:@"foo"]];
        }];
    }];
    
    [valueProcessor processInputValue:@"test" inputError:nil context:@"context"];
    
    XCTAssertNil(valueProcessor.outputError, @"unexpected error");
    XCTAssertNotNil(valueProcessor.outputValue, @"missing value");
    XCTAssertEqualObjects(valueProcessor.outputValue, @"testfoo", @"wrong value");
}

- (void)testError
{
    RKLegacyPostProcessor *errorProcessor = [[RKLegacyPostProcessor alloc] initWithBlock:^RKPossibility *(RKPossibility *maybeData, id context) {
        XCTAssertNotNil(context, @"context missing");
        XCTAssertEqual(maybeData.state, kRKPossibilityStateValue, @"wrong possibility state");
        
        return [maybeData refineValue:^RKPossibility *(NSString *value) {
            return [[RKPossibility alloc] initWithError:[NSError errorWithDomain:@"SillyErrorDomain"
                                                                            code:'dumb'
                                                                        userInfo:@{NSLocalizedDescriptionKey: @"It worked!"}]];
        }];
    }];
    
    [errorProcessor processInputValue:@"test" inputError:nil context:@"context"];
    
    XCTAssertNotNil(errorProcessor.outputError, @"missing error");
    XCTAssertNil(errorProcessor.outputValue, @"unexpected value");
}

@end
