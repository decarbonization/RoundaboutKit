//
//  RKPromiseTests.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import "RKPromiseTests.h"
#import "RKMockPromise.h"

#define DEFAULT_DURATION            0.3
#define DEFAULT_TIMEOUT             0.8

#pragma mark -

@interface RKPromiseTests ()

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
                                                              duration:DEFAULT_DURATION
                                                             canCancel:YES
                                                     numberOfSuccesses:1];
    
    __block BOOL finished = NO;
    __block BOOL succeeded = NO;
    __block id outValue = nil;
    RKRealize(testPromise, ^(id data) {
        finished = YES;
        
        outValue = data;
        succeeded = YES;
    }, ^(NSError *error) {
        finished = YES;
        
        succeeded = NO;
    });
    
    [RunLoopHelper runFor:DEFAULT_TIMEOUT];
    
    STAssertTrue(finished, @"RKRealize timed out generating value.");
    STAssertTrue(succeeded, @"RKRealize failed to generate value.");
    STAssertNotNil(outValue, @"RKRealize yielded nil value.");
}

- (void)testFailedRealize
{
    RKMockPromise *testPromise = [[RKMockPromise alloc] initWithResult:self.errorPossibility
                                                              duration:DEFAULT_DURATION
                                                             canCancel:YES
                                                     numberOfSuccesses:1];
    
    __block BOOL finished = NO;
    __block BOOL failed = NO;
    __block NSError *outError = nil;
    RKRealize(testPromise, ^(id data) {
        finished = YES;
        failed = NO;
    }, ^(NSError *error) {
        finished = YES;
        failed = YES;
        
        outError = error;
    });
    
    [RunLoopHelper runFor:DEFAULT_TIMEOUT];
    
    STAssertTrue(finished, @"RKRealize timed out generating error.");
    STAssertTrue(failed, @"RKRealize failed to generate error.");
    STAssertNotNil(outError, @"RKRealize yielded nil error.");
}

#pragma mark -

- (void)testCancel
{
    RKMockPromise *testPromise = [[RKMockPromise alloc] initWithResult:self.successPossibility
                                                              duration:DEFAULT_DURATION
                                                             canCancel:YES
                                                     numberOfSuccesses:1];
    
    __block BOOL finished = NO;
    RKRealize(testPromise, ^(id data) {
        finished = YES;
    }, ^(NSError *error) {
        finished = YES;
    });
    [testPromise cancel:nil];
    
    [RunLoopHelper runFor:0.5];
    
    STAssertFalse(finished, @"RKRealize yielded after being canceled.");
}

- (void)testUncancelable
{
    RKMockPromise *testPromise = [[RKMockPromise alloc] initWithResult:self.successPossibility
                                                              duration:DEFAULT_DURATION
                                                             canCancel:NO
                                                     numberOfSuccesses:1];
    
    STAssertThrows([testPromise cancel:nil], @"cancel did not throw for non-cancelable promise.");
}

#pragma mark -

- (void)testMultiPart
{
    NSUInteger const kNumberOfSuccesses = 4;
    
    RKMockPromise *testPromise = [[RKMockPromise alloc] initWithResult:self.successPossibility
                                                              duration:0.1
                                                             canCancel:YES
                                                     numberOfSuccesses:kNumberOfSuccesses];
    
    __block BOOL finished = NO;
    __block NSUInteger accumulator = 0;
    RKRealize(testPromise, ^(id data) {
        finished = YES;
        accumulator++;
    }, ^(NSError *error) {
        finished = YES;
    });
    
    [RunLoopHelper runFor:0.6];
    
    STAssertTrue(finished, @"RKRealize timed out");
    STAssertEquals(accumulator, kNumberOfSuccesses, @"Multi-part promise yielded less times than expected");
}

#pragma mark -

- (void)testRealizeMultiple
{
    NSUInteger const kNumberOfPromises = 5;
    NSArray *promises = RKCollectionGenerateArray(kNumberOfPromises, ^(NSUInteger promiseNumber) {
        return [[RKMockPromise alloc] initWithResult:[[RKPossibility alloc] initWithValue:@(promiseNumber)]
                                            duration:0.1
                                           canCancel:YES
                                   numberOfSuccesses:1];
    });
    
    __block BOOL finished = NO;
    __block NSArray *results = nil;
    RKRealizePromises(promises, ^(NSArray *possibilities) {
        finished = YES;
        results = RKCollectionMapToArray(possibilities, ^id(RKPossibility *probablyValue) {
            STAssertEquals(probablyValue.state, kRKPossibilityStateValue, @"A promise unexpectedly failed");
            
            return probablyValue.value;
        });
    });
    
    [RunLoopHelper runUntil:^BOOL{ return (results != nil); }];
    
    STAssertTrue(finished, @"RKRealizePromises timed out");
    STAssertEqualObjects(results, (@[ @0, @1, @2, @3, @4 ]), @"RKRealizePromises yielded wrong value");
}

@end
