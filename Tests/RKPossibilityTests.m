//
//  RKPossibilityTests.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 4/12/13.
//
//

#import <XCTest/XCTest.h>

@interface RKPossibilityTests : XCTestCase

@end

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

#pragma mark - Convenience

- (void)testValuesFromArrayOfPossibilities
{
    NSArray *testArray = @[ [RKPossibility possibilityWithValue:@"hello"],
                            [RKPossibility possibilityWithValue:@"hallo"],
                            [RKPossibility possibilityWithError:_testError],
                            [RKPossibility possibilityWithValue:@"ahoyhoy"],
                            [RKPossibility possibilityWithError:_testError] ];
    
    NSArray *values = [RKPossibility valuesFromPossibilities:testArray];
    XCTAssertNotNil(values, @"missing values");
    XCTAssertEqual(values.count, (NSUInteger)3, @"wrong number of values");
    XCTAssertEqualObjects(values, (@[@"hello", @"hallo", @"ahoyhoy"]), @"wrong results");
}

- (void)testErrorsFromArrayOfPossibilities
{
    NSError *error1 = [NSError errorWithDomain:NSPOSIXErrorDomain code:'parm' userInfo:@{NSLocalizedDescriptionKey: @"paramErr"}];
    NSError *error2 = [NSError errorWithDomain:NSPOSIXErrorDomain code:'food' userInfo:@{NSLocalizedDescriptionKey: @"not enough food provided"}];
    
    NSArray *testArray = @[ [RKPossibility possibilityWithValue:@"hello"],
                            [RKPossibility possibilityWithError:error1],
                            [RKPossibility possibilityWithValue:@"ahoyhoy"],
                            [RKPossibility possibilityWithError:error2] ];
    
    NSArray *errors = [RKPossibility errorsFromPossibilities:testArray];
    XCTAssertNotNil(errors, @"missing values");
    XCTAssertEqual(errors.count, (NSUInteger)2, @"wrong number of values");
    XCTAssertEqualObjects(errors, (@[error1, error2]), @"wrong results");
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

- (void)testEmptySingleton
{
    RKPossibility *empty1 = [RKPossibility emptyPossibility];
    RKPossibility *empty2 = [RKPossibility emptyPossibility];
    XCTAssertEqualObjects(empty1, empty2, @"empty singleton method is not working");
}

#pragma mark - Refinement

- (void)testRefinementValueToValue
{
    RKPossibility *possibility = [RKPossibility possibilityWithValue:_testObject];
    RKPossibility *refinedPossibility = [possibility refineValue:^RKPossibility *(NSString *value) {
        return [RKPossibility possibilityWithValue:[value stringByAppendingString:@" foo"]];
    }];
    XCTAssertEqual(refinedPossibility.state, kRKPossibilityStateValue, @"wrong state");
    XCTAssertEqualObjects(refinedPossibility.value, @"This is test, only a test foo", @"RKRefinePossibility returned wrong result");
}

- (void)testRefinementValueToError
{
    RKPossibility *possibility = [RKPossibility possibilityWithValue:_testObject];
    RKPossibility *refinedPossibility = [possibility refineValue:^RKPossibility *(NSString *value) {
        return [RKPossibility possibilityWithError:_testError];
    }];
    XCTAssertEqual(refinedPossibility.state, kRKPossibilityStateError, @"wrong state");
    XCTAssertEqualObjects(refinedPossibility.error, _testError, @"RKRefinePossibility returned wrong result");
}

- (void)testRefinementValueToEmpty
{
    RKPossibility *possibility = [RKPossibility possibilityWithValue:_testObject];
    RKPossibility *refinedPossibility = [possibility refineValue:^RKPossibility *(NSString *value) {
        return [RKPossibility emptyPossibility];
    }];
    XCTAssertEqual(refinedPossibility.state, kRKPossibilityStateEmpty, @"wrong state");
}

#pragma mark -

- (void)testRefinementErrorToValue
{
    RKPossibility *possibility = [RKPossibility possibilityWithError:_testError];
    RKPossibility *refinedPossibility = [possibility refineError:^RKPossibility *(NSError *error) {
        return [RKPossibility possibilityWithValue:@"hello, world"];
    }];
    XCTAssertEqual(refinedPossibility.state, kRKPossibilityStateValue, @"wrong state");
    XCTAssertEqualObjects(refinedPossibility.value, @"hello, world", @"RKRefinePossibility returned wrong result");
}

- (void)testRefinementErrorToError
{
    RKPossibility *possibility = [RKPossibility possibilityWithError:_testError];
    RKPossibility *refinedPossibility = [possibility refineError:^RKPossibility *(NSError *error) {
        return [RKPossibility possibilityWithError:_testError];
    }];
    XCTAssertEqual(refinedPossibility.state, kRKPossibilityStateError, @"wrong state");
    XCTAssertEqualObjects(refinedPossibility.error, _testError, @"RKRefinePossibility returned wrong result");
}

- (void)testRefinementErrorToEmpty
{
    RKPossibility *possibility = [RKPossibility possibilityWithError:_testError];
    RKPossibility *refinedPossibility = [possibility refineError:^RKPossibility *(NSError *error) {
        return [RKPossibility emptyPossibility];
    }];
    XCTAssertEqual(refinedPossibility.state, kRKPossibilityStateEmpty, @"wrong state");
}

#pragma mark -

- (void)testRefinementEmptyToValue
{
    RKPossibility *possibility = [RKPossibility emptyPossibility];
    RKPossibility *refinedPossibility = [possibility refineEmpty:^{
        return [RKPossibility possibilityWithValue:@"hello, world"];
    }];
    XCTAssertEqual(refinedPossibility.state, kRKPossibilityStateValue, @"wrong state");
    XCTAssertEqualObjects(refinedPossibility.value, @"hello, world", @"RKRefinePossibility returned wrong result");
}

- (void)testRefinementEmptyToError
{
    RKPossibility *possibility = [RKPossibility emptyPossibility];
    RKPossibility *refinedPossibility = [possibility refineEmpty:^{
        return [RKPossibility possibilityWithError:_testError];
    }];
    XCTAssertEqual(refinedPossibility.state, kRKPossibilityStateError, @"wrong state");
    XCTAssertEqualObjects(refinedPossibility.error, _testError, @"RKRefinePossibility returned wrong result");
}

- (void)testRefinementEmptyToEmpty
{
    RKPossibility *possibility = [RKPossibility emptyPossibility];
    RKPossibility *refinedPossibility = [possibility refineEmpty:^{
        return [RKPossibility emptyPossibility];
    }];
    XCTAssertEqual(refinedPossibility.state, kRKPossibilityStateEmpty, @"wrong state");
}

#pragma mark - Matching

- (void)testValueMatching
{
    RKPossibility *possibility = [RKPossibility possibilityWithValue:_testObject];
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

- (void)testErrorMatching
{
    RKPossibility *possibility = [RKPossibility possibilityWithError:_testError];
    [possibility whenValue:^(id value) {
        XCTAssertTrue(NO, @"RKMatchPossibility failed to match error");
    }];
    [possibility whenEmpty:^{
        XCTAssertTrue(NO, @"RKMatchPossibility failed to match error");
    }];
    [possibility whenError:^(NSError *error) {
        XCTAssertTrue(YES, @"RKMatchPossibility failed to match error");
    }];
}

- (void)testEmptyMatching
{
    RKPossibility *possibility = [RKPossibility emptyPossibility];
    [possibility whenValue:^(id value) {
        XCTAssertTrue(NO, @"RKMatchPossibility failed to match empty");
    }];
    [possibility whenEmpty:^{
        XCTAssertTrue(YES, @"RKMatchPossibility failed to match empty");
    }];
    [possibility whenError:^(NSError *error) {
        XCTAssertTrue(NO, @"RKMatchPossibility failed to match empty");
    }];
}

@end
