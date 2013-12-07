//
//  RKPossibilityTests.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 4/12/13.
//
//

#import "RKPossibilityTests.h"

@implementation RKPossibilityTests {
    NSString *_testObject;
    NSError *_testError;
}

- (void)setUp
{
    [super setUp];
    
    _testObject = @"This is test, only a test";
    _testError = [NSError errorWithDomain:NSPOSIXErrorDomain code:'fail' userInfo:@{NSLocalizedDescriptionKey: @"everything is broken!"}];
}

#pragma mark - States

- (void)testValue
{
    RKPossibility *possibility = [[RKPossibility alloc] initWithValue:_testObject];
    XCTAssertEqual(possibility.state, kRKPossibilityStateValue, @"RKPossibility is in unexpected state");
    XCTAssertEqualObjects(possibility.value, _testObject, @"RKPossibility has unexpected value");
    XCTAssertNil(possibility.error, @"RKPossibility has unexpected error");
}

- (void)testError
{
    RKPossibility *possibility = [[RKPossibility alloc] initWithError:_testError];
    XCTAssertEqual(possibility.state, kRKPossibilityStateError, @"RKPossibility is in unexpected state");
    XCTAssertEqualObjects(possibility.error, _testError, @"RKPossibility has unexpected value");
    XCTAssertNil(possibility.value, @"RKPossibility has unexpected value");
}

- (void)testEmpty
{
    RKPossibility *possibility = [[RKPossibility alloc] initEmpty];
    XCTAssertEqual(possibility.state, kRKPossibilityStateEmpty, @"RKPossibility is in unexpected state");
    XCTAssertNil(possibility.value, @"RKPossibility has unexpected value");
    XCTAssertNil(possibility.error, @"RKPossibility has unexpected error");
}

#pragma mark - Utility Functions

- (void)testRefinement
{
    RKPossibility *possibility = [[RKPossibility alloc] initWithValue:_testObject];
    RKPossibility *refinedPossibility = [possibility refineValue:^RKPossibility *(NSString *value) {
        return [[RKPossibility alloc] initWithValue:[value stringByAppendingString:@" foo"]];
    }];
    XCTAssertEqualObjects(refinedPossibility.value, @"This is test, only a test foo", @"RKRefinePossibility returned wrong result");
}

- (void)testMatching
{
    RKPossibility *possibility = [[RKPossibility alloc] initWithValue:_testObject];
    [possibility whenValue:^(id value) {
        XCTAssertTrue(YES, @"RKMatchPossibility failed to match value");
    }];
    [possibility whenEmpty:^{
        XCTAssertTrue(NO, @"RKMatchPossibility failed to match value");
    }];
    [possibility whenError:^(NSError *error) {
        XCTAssertTrue(NO, @"RKMatchPossibility failed to match value");
    }];
}

@end
