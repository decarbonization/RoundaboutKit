//
//  RKAwaitTests.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import "RKAwaitTests.h"
#import "RKMockPromise.h"

@interface RKAwaitTests ()

@property RKPossibility *successPossibility;
@property RKPossibility *errorPossibility;

@end

@implementation RKAwaitTests

- (void)setUp
{
    [super setUp];
    
    self.successPossibility = [[RKPossibility alloc] initWithValue:@"What lovely weather we're having."];
    self.errorPossibility = [[RKPossibility alloc] initWithError:[NSError errorWithDomain:@"RKFictitiousErrorDomain"
                                                                                     code:'fail'
                                                                                 userInfo:@{NSLocalizedDescriptionKey: @"An unknown fictitious error occurred."}]];
}

#pragma mark -

- (void)testSuccessAwait
{
    RKMockPromise *testPromise = [[RKMockPromise alloc] initWithResult:self.successPossibility
                                                              duration:0.05
                                                             canCancel:YES
                                                     numberOfSuccesses:1];
    
    NSError *error = nil;
    id result = RKAwait(testPromise, &error);
    STAssertNotNil(result, @"RKAwait failed to yield value");
    STAssertNil(error, @"RKAwait unexpectedly yielded error");
}

- (void)testErrorAwait
{
    RKMockPromise *testPromise = [[RKMockPromise alloc] initWithResult:self.errorPossibility
                                                              duration:0.05
                                                             canCancel:YES
                                                     numberOfSuccesses:1];
    
    NSError *error = nil;
    id result = RKAwait(testPromise, &error);
    STAssertNil(result, @"RKAwait unexpectedly yielded error");
    STAssertNotNil(error, @"RKAwait failed to yield error");
}

- (void)testThrowingAwait
{
    RKMockPromise *testPromise = [[RKMockPromise alloc] initWithResult:self.errorPossibility
                                                              duration:0.05
                                                             canCancel:YES
                                                     numberOfSuccesses:1];
    STAssertThrows(RKAwait(testPromise), @"RKAwait unexpectedly did not throw");
}

@end
