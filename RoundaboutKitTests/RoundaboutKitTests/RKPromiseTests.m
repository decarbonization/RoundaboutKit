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

static void runloop_run_for(NSTimeInterval seconds)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

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
    
    runloop_run_for(DEFAULT_TIMEOUT);
    
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
    
    runloop_run_for(DEFAULT_TIMEOUT);
    
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
    
    runloop_run_for(0.5);
    
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
    
    runloop_run_for(1.0);
    
    STAssertTrue(finished, @"RKRealize timed out");
    STAssertEquals(accumulator, kNumberOfSuccesses, @"Multi-part promise yielded less times than expected");
}

@end
