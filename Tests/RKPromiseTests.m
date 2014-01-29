//
//  RKPromiseTests.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import <XCTest/XCTest.h>
#import "RKMockPromise.h"

#define DEFAULT_DURATION            0.3
#define DEFAULT_TIMEOUT             0.8

#pragma mark -


@interface RKPromiseTests : XCTestCase

@property RKPossibility *successPossibility;
@property RKPossibility *errorPossibility;

@end

@implementation RKPromiseTests

/*
 *  Very bad things will happen if any of these tests unintentionally fail after changes.
 */

- (void)setUp
{
    [super setUp];
    
    self.successPossibility = [[RKPossibility alloc] initWithValue:@"What lovely weather we're having."];
    self.errorPossibility = [[RKPossibility alloc] initWithError:[NSError errorWithDomain:@"RKFictitiousErrorDomain"
                                                                                     code:'fail'
                                                                                 userInfo:@{NSLocalizedDescriptionKey: @"An unknown fictitious error occurred."}]];
}

#pragma mark -

- (void)testSuccessfulRealize
{
    RKMockPromise *testPromise = [[RKMockPromise alloc] initWithResult:self.successPossibility
                                                              duration:DEFAULT_DURATION];
    
    __block BOOL finished = NO;
    __block BOOL succeeded = NO;
    __block id outValue = nil;
    [testPromise then:^(id data) {
        finished = YES;
        
        outValue = data;
        succeeded = YES;
    } otherwise:^(NSError *error) {
        finished = YES;
        
        succeeded = NO;
    }];
    
    [RunLoopHelper runFor:DEFAULT_TIMEOUT];
    
    XCTAssertTrue(finished, @"RKRealize timed out generating value.");
    XCTAssertTrue(succeeded, @"RKRealize failed to generate value.");
    XCTAssertNotNil(outValue, @"RKRealize yielded nil value.");
}

- (void)testFailedRealize
{
    RKMockPromise *testPromise = [[RKMockPromise alloc] initWithResult:self.errorPossibility
                                                              duration:DEFAULT_DURATION];
    
    __block BOOL finished = NO;
    __block BOOL failed = NO;
    __block NSError *outError = nil;
    [testPromise then:^(id data) {
        finished = YES;
        failed = NO;
    } otherwise:^(NSError *error) {
        finished = YES;
        failed = YES;
        
        outError = error;
    }];
    
    [RunLoopHelper runFor:DEFAULT_TIMEOUT];
    
    XCTAssertTrue(finished, @"RKRealize timed out generating error.");
    XCTAssertTrue(failed, @"RKRealize failed to generate error.");
    XCTAssertNotNil(outError, @"RKRealize yielded nil error.");
}

#pragma mark -

- (void)testRealizeMultiple
{
    NSUInteger const kNumberOfPromises = 5;
    NSArray *promises = RKCollectionGenerateArray(kNumberOfPromises, ^(NSUInteger promiseNumber) {
        return [RKPromise acceptedPromiseWithValue:@(promiseNumber)];
    });
    
    __block BOOL finished = NO;
    __block NSArray *results = nil;
    [[RKPromise when:promises] then:^(NSArray *possibilities) {
        finished = YES;
        results = RKCollectionMapToArray(possibilities, ^id(RKPossibility *probablyValue) {
            XCTAssertEqual(probablyValue.state, kRKPossibilityStateValue, @"A promise unexpectedly failed");
            
            return probablyValue.value;
        });
    } otherwise:^(NSError *error) {
        //Do nothing
    }];
    
    BOOL finishedNaturally = [RunLoopHelper runUntil:^BOOL{ return (results != nil); } orSecondsHasElapsed:1.0];
    
    XCTAssertTrue(finishedNaturally, @"realize timed out");
    XCTAssertTrue(finished, @"RKRealizePromises timed out");
    XCTAssertEqualObjects(results, (@[ @0, @1, @2, @3, @4 ]), @"RKRealizePromises yielded wrong value");
}

#pragma mark -

- (void)testExceptionSafety
{
    RKSimplePostProcessor *throwingPostProcessor = [[RKSimplePostProcessor alloc] initWithBlock:^RKPossibility *(RKPossibility *maybeData, id context) {
        [NSException raise:NSInternalInconsistencyException format:@"Just not gonna work."];
        return nil;
    }];
    
    dispatch_block_t test = ^{
        //This test is encapsulated in a block because if RKPromise is not
        //property exception safe, the internal mutex teardown in -[RKPromise dealloc]
        //will raise an exception indicating an internal deadlock. As such, the
        //only way to test this in ARC is to tie the promise's lifecycle to a scope.
        RKPromise *testPromise = [RKPromise new];
        [testPromise addPostProcessors:@[ throwingPostProcessor ]];
        XCTAssertThrows([testPromise accept:@"does not matter"], @"expected exception");
    };
    
    XCTAssertNoThrow(test(), @"unexpected exception");
}

#pragma mark - Test Await

- (void)testSuccessAwait
{
    RKMockPromise *testPromise = [[RKMockPromise alloc] initWithResult:self.successPossibility
                                                              duration:0.05];
    
    NSError *error = nil;
    id result = [testPromise waitForRealization:&error];
    XCTAssertNotNil(result, @"RKAwait failed to yield value");
    XCTAssertNil(error, @"RKAwait unexpectedly yielded error");
}

- (void)testErrorAwait
{
    RKMockPromise *testPromise = [[RKMockPromise alloc] initWithResult:self.errorPossibility
                                                              duration:0.05];
    
    NSError *error = nil;
    id result = [testPromise waitForRealization:&error];
    XCTAssertNil(result, @"RKAwait unexpectedly yielded error");
    XCTAssertNotNil(error, @"RKAwait failed to yield error");
}

#pragma mark - Test Post Processors

- (void)testSuccessPostProcessor
{
    RKSimplePostProcessor *goodProcessor = [[RKSimplePostProcessor alloc] initWithBlock:^RKPossibility *(RKPossibility *maybeData, id context) {
        return [maybeData refineValue:^RKPossibility *(NSString *string) {
            return [[RKPossibility alloc] initWithValue:[string stringByAppendingString:@"foo"]];
        }];
    }];
    
    RKPromise *goodPromise = [RKPromise new];
    [goodPromise addPostProcessors:@[ goodProcessor ]];
    [goodPromise accept:@"test"];
    
    NSError *error = nil;
    id value = [goodPromise waitForRealization:&error];
    XCTAssertNil(error, @"unexpected error");
    XCTAssertNotNil(value, @"missing value");
    XCTAssertEqualObjects(value, @"testfoo", @"unexpected value");
}

- (void)testFailurePostProcessor
{
    RKSimplePostProcessor *badProcessor = [[RKSimplePostProcessor alloc] initWithBlock:^RKPossibility *(RKPossibility *maybeData, id context) {
        return [maybeData refineValue:^RKPossibility *(NSString *string) {
            return [[RKPossibility alloc] initWithError:[NSError errorWithDomain:@"SillyErrorDomain"
                                                                            code:'dumb'
                                                                        userInfo:@{NSLocalizedDescriptionKey: @"It worked!"}]];
        }];
    }];
    
    RKPromise *goodPromise = [RKPromise new];
    [goodPromise addPostProcessors:@[ badProcessor ]];
    [goodPromise accept:@"test"];
    
    NSError *error = nil;
    id value = [goodPromise waitForRealization:&error];
    XCTAssertNotNil(error, @"missing error");
    XCTAssertNil(value, @"unexpected value value");
}

@end
