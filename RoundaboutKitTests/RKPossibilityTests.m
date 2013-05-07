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
    STAssertEquals(possibility.state, kRKPossibilityStateValue, @"RKPossibility is in unexpected state");
    STAssertEqualObjects(possibility.value, _testObject, @"RKPossibility has unexpected value");
    STAssertNil(possibility.error, @"RKPossibility has unexpected error");
}

- (void)testError
{
    RKPossibility *possibility = [[RKPossibility alloc] initWithError:_testError];
    STAssertEquals(possibility.state, kRKPossibilityStateError, @"RKPossibility is in unexpected state");
    STAssertEqualObjects(possibility.error, _testError, @"RKPossibility has unexpected value");
    STAssertNil(possibility.value, @"RKPossibility has unexpected value");
}

- (void)testEmpty
{
    RKPossibility *possibility = [[RKPossibility alloc] initEmpty];
    STAssertEquals(possibility.state, kRKPossibilityStateEmpty, @"RKPossibility is in unexpected state");
    STAssertNil(possibility.value, @"RKPossibility has unexpected value");
    STAssertNil(possibility.error, @"RKPossibility has unexpected error");
}

#pragma mark - Utility Functions

- (void)testRefinePossibility
{
    RKPossibility *possibility = [[RKPossibility alloc] initWithValue:_testObject];
    RKPossibility *refinedPossibility = RKRefinePossibility(possibility, ^RKPossibility *(NSString *value) {
        return [[RKPossibility alloc] initWithValue:[value stringByAppendingString:@" foo"]];
    }, kRKPossibilityDefaultEmptyRefiner, kRKPossibilityDefaultErrorRefiner);
    STAssertEqualObjects(refinedPossibility.value, @"This is test, only a test foo", @"RKRefinePossibility returned wrong result");
}

- (void)testMatchPossibility
{
    RKPossibility *possibility = [[RKPossibility alloc] initWithValue:_testObject];
    RKMatchPossibility(possibility, ^(id value) {
        STAssertTrue(YES, @"RKMatchPossibility failed to match value");
    }, ^{
        STAssertTrue(NO, @"RKMatchPossibility failed to match value");
    }, ^(NSError *error) {
        STAssertTrue(NO, @"RKMatchPossibility failed to match value");
    });
}

@end
