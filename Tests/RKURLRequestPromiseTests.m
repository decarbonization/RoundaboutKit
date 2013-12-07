//
//  RKURLRequestPromiseTests.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import <XCTest/XCTest.h>
#import "RKMockURLProtocol.h"
#import "RKMockURLRequestPromiseCacheManager.h"

#define PLAIN_TEXT_URL_STRING   @"http://test/plaintext"
#define PLAIN_TEXT_STRING       (@"hello, world!")


@interface RKURLRequestPromiseTests : XCTestCase

@property RKConnectivityManager *connectivityManager;

@end

@implementation RKURLRequestPromiseTests

- (void)registerPredeterminedResponses
{
    [RKMockURLProtocol on:[NSURL URLWithString:PLAIN_TEXT_URL_STRING]
               withMethod:@"GET"
          yieldStatusCode:200
                  headers:@{@"Content-Type": @"plain-text;charset=utf-8", @"Etag": @"SomeArbitraryValue", @"Status": @"200"}
                     data:[PLAIN_TEXT_STRING dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)setUp
{
    [super setUp];
    
    self.connectivityManager = [[RKConnectivityManager alloc] initWithHostName:@"localhost"];
    
    [self registerPredeterminedResponses];
}

- (void)tearDown
{
    [super tearDown];
    
    [RKMockURLProtocol removeAllRoutes];
}

#pragma mark -

- (RKURLRequestPromise *)makePlainTextWithNoCacheRequest
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:PLAIN_TEXT_URL_STRING]];
    RKURLRequestPromise *testPromise = [[RKURLRequestPromise alloc] initWithRequest:request
                                                                       cacheManager:nil
                                                                useCacheWhenOffline:NO
                                                                       requestQueue:[RKQueueManager commonQueue]];
    testPromise.connectivityManager = self.connectivityManager;
    return testPromise;
}

- (void)testPlainTextRequest
{
    RKURLRequestPromise *testPromise = [self makePlainTextWithNoCacheRequest];
    
    NSError *error = nil;
    NSData *result = [testPromise waitForRealization:&error];
    XCTAssertNotNil(result, @"RKAwait unexpectedly failed");
    
    NSString *resultString = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(resultString, PLAIN_TEXT_STRING, @"Incorrect result");
}

#pragma mark -

- (void)testPreflightAssumptions
{
    RKURLRequestPromise *testPromise = [self makePlainTextWithNoCacheRequest];
    
    __block BOOL hadRequest = NO;
    __block BOOL hadOutError = NO;
    __block BOOL hadSecondaryThread = NO;
    testPromise.preflight = ^NSURLRequest *(NSURLRequest *request, NSError **outError) {
        hadRequest = (request != nil);
        hadOutError = (outError != NULL);
        hadSecondaryThread = ![NSThread isMainThread];
        
        return request;
    };
    
    NSError *error = nil;
    NSData *result = [testPromise waitForRealization:&error];
    XCTAssertNotNil(result, @"RKAwait unexpectedly failed");
    
    XCTAssertTrue(hadRequest, @"No request was passed to preflight");
    XCTAssertTrue(hadOutError, @"No outError was passed to preflight");
    XCTAssertTrue(hadSecondaryThread, @"Preflight was invoked from main thread");
}

- (void)testPostProcessorAssumptions
{
    RKURLRequestPromise *testPromise = [self makePlainTextWithNoCacheRequest];
    
    __block BOOL hadPossibility = NO;
    __block BOOL hadSecondaryThread = NO;
    testPromise.postProcessor = ^RKPossibility *(RKPossibility *maybeData, RKURLRequestPromise *request) {
        hadPossibility = (maybeData != nil);
        hadSecondaryThread = ![NSThread isMainThread];
        
        return maybeData;
    };
    
    NSError *error = nil;
    NSData *result = [testPromise waitForRealization:&error];
    XCTAssertNotNil(result, @"RKAwait unexpectedly failed");
    
    XCTAssertTrue(hadPossibility, @"Post-processor was given no data");
    XCTAssertTrue(hadSecondaryThread, @"Post-processor was invoked from main thread");
}

#pragma mark -

- (void)testCacheManagerAssumptionsWithSameEtag
{
    NSString *const kCacheIdentifier = PLAIN_TEXT_URL_STRING;
    
    NSDictionary *items = @{
        kCacheIdentifier: @{
            kRKMockURLRequestPromiseCacheManagerItemRevisionKey: @"SomeArbitraryValue",
            kRKMockURLRequestPromiseCacheManagerItemDataKey: [PLAIN_TEXT_STRING dataUsingEncoding:NSUTF8StringEncoding],
        },
    };
    RKMockURLRequestPromiseCacheManager *cacheManager = [[RKMockURLRequestPromiseCacheManager alloc] initWithItems:items];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:PLAIN_TEXT_URL_STRING]];
    RKURLRequestPromise *testPromise = [[RKURLRequestPromise alloc] initWithRequest:request
                                                                       cacheManager:cacheManager
                                                                useCacheWhenOffline:NO
                                                                       requestQueue:[RKQueueManager commonQueue]];
    testPromise.cacheIdentifier = kCacheIdentifier;
    testPromise.connectivityManager = self.connectivityManager;
    
    NSError *error = nil;
    NSData *result = [testPromise waitForRealization:&error];
    XCTAssertNotNil(result, @"RKAwait unexpectedly failed");
    
    XCTAssertFalse(cacheManager.wasCalledFromMainThread, @"Cache manager was called from main thread");
    XCTAssertTrue(cacheManager.revisionForIdentifierWasCalled, @"revisionForIdentifier was not called");
    XCTAssertFalse(cacheManager.cacheDataForIdentifierWithRevisionErrorWasCalled, @"cacheDataForIdentifierWithRevisionError was not called");
    XCTAssertTrue(cacheManager.cachedDataForIdentifierErrorWasCalled, @"cachedDataForIdentifierError was not called");
    XCTAssertFalse(cacheManager.removeCacheForIdentifierErrorWasCalled, @"removeCacheForIdentifierErrorWasCalled was called");
    
    NSString *resultString = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(resultString, PLAIN_TEXT_STRING, @"Wrong result was given");
}

- (void)testCacheManagerAssumptionsWithDifferentEtag
{
    NSString *const kCacheIdentifier = PLAIN_TEXT_URL_STRING;
    
    NSDictionary *items = @{
        kCacheIdentifier: @{
            kRKMockURLRequestPromiseCacheManagerItemRevisionKey: @"SomeOtherArbitraryValue",
            kRKMockURLRequestPromiseCacheManagerItemDataKey: [@"This string should not be propagated" dataUsingEncoding:NSUTF8StringEncoding],
        },
    };
    RKMockURLRequestPromiseCacheManager *cacheManager = [[RKMockURLRequestPromiseCacheManager alloc] initWithItems:items];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:PLAIN_TEXT_URL_STRING]];
    RKURLRequestPromise *testPromise = [[RKURLRequestPromise alloc] initWithRequest:request
                                                                       cacheManager:cacheManager
                                                                useCacheWhenOffline:NO
                                                                       requestQueue:[RKQueueManager commonQueue]];
    testPromise.cacheIdentifier = kCacheIdentifier;
    testPromise.connectivityManager = self.connectivityManager;
    
    NSError *error = nil;
    NSData *result = [testPromise waitForRealization:&error];
    XCTAssertNotNil(result, @"RKAwait unexpectedly failed");
    
    XCTAssertFalse(cacheManager.wasCalledFromMainThread, @"Cache manager was called from main thread");
    XCTAssertTrue(cacheManager.revisionForIdentifierWasCalled, @"revisionForIdentifier was not called");
    XCTAssertTrue(cacheManager.cacheDataForIdentifierWithRevisionErrorWasCalled, @"cacheDataForIdentifierWithRevisionError was not called");
    XCTAssertFalse(cacheManager.cachedDataForIdentifierErrorWasCalled, @"cachedDataForIdentifierError was not called");
    XCTAssertFalse(cacheManager.removeCacheForIdentifierErrorWasCalled, @"removeCacheForIdentifierErrorWasCalled was called");
    
    NSString *resultString = [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(resultString, PLAIN_TEXT_STRING, @"Wrong result was given");
}

- (void)testCacheManagerAssumptionsAboutFailure
{
    NSString *const kCacheIdentifier = PLAIN_TEXT_URL_STRING;
    
    NSDictionary *items = @{
        kCacheIdentifier: @{
            kRKMockURLRequestPromiseCacheManagerItemRevisionKey: @"SomeArbitraryValue",
            kRKMockURLRequestPromiseCacheManagerItemErrorKey: [NSError errorWithDomain:@"IgnoredErrorDomain"
                                                                                  code:'ever'
                                                                              userInfo:@{NSLocalizedDescriptionKey: @"Arbitrary error!"}],
        },
    };
    RKMockURLRequestPromiseCacheManager *cacheManager = [[RKMockURLRequestPromiseCacheManager alloc] initWithItems:items];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:PLAIN_TEXT_URL_STRING]];
    RKURLRequestPromise *testPromise = [[RKURLRequestPromise alloc] initWithRequest:request
                                                                       cacheManager:cacheManager
                                                                useCacheWhenOffline:NO
                                                                       requestQueue:[RKQueueManager commonQueue]];
    testPromise.cacheIdentifier = kCacheIdentifier;
    testPromise.connectivityManager = self.connectivityManager;
    
    NSError *error = nil;
    NSData *result = [testPromise waitForRealization:&error];
    XCTAssertNil(result, @"RKAwait unexpectedly succeeded");
    XCTAssertNotNil(error, @"RKAwait propagated no error");
    XCTAssertTrue(cacheManager.removeCacheForIdentifierErrorWasCalled, @"removeCacheForIdentifierErrorWasCalled was not called");
    
    XCTAssertFalse(cacheManager.wasCalledFromMainThread, @"Cache manager was called from main thread");
    XCTAssertEqualObjects(error.domain, RKURLRequestPromiseErrorDomain, @"Error has wrong domain");
    XCTAssertEqual(error.code, kRKURLRequestPromiseErrorCannotLoadCache, @"Error has wrong code");
}

- (void)testCacheManagerPreloading
{
    NSString *const kCacheIdentifier = PLAIN_TEXT_URL_STRING;
    
    NSDictionary *items = @{
        kCacheIdentifier: @{
            kRKMockURLRequestPromiseCacheManagerItemRevisionKey: @"SomeArbitraryValue",
            kRKMockURLRequestPromiseCacheManagerItemDataKey: [PLAIN_TEXT_STRING dataUsingEncoding:NSUTF8StringEncoding],
        },
    };
    RKMockURLRequestPromiseCacheManager *cacheManager = [[RKMockURLRequestPromiseCacheManager alloc] initWithItems:items];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:PLAIN_TEXT_URL_STRING]];
    RKURLRequestPromise *testPromise = [[RKURLRequestPromise alloc] initWithRequest:request
                                                                       cacheManager:cacheManager
                                                                useCacheWhenOffline:NO
                                                                       requestQueue:[RKQueueManager commonQueue]];
    testPromise.cacheIdentifier = kCacheIdentifier;
    testPromise.connectivityManager = self.connectivityManager;
    
    __block BOOL hasLoaded = NO;
    __block RKPossibility *maybeValue = nil;
    [testPromise loadCachedDataWithBlock:^(RKPossibility *maybeData) {
        hasLoaded = YES;
        maybeValue = maybeData;
    }];
    
    BOOL finishedNaturally = [RunLoopHelper runUntil:^BOOL{ return (hasLoaded == YES); } orSecondsHasElapsed:1.0];
    
    XCTAssertTrue(finishedNaturally, @"load timed out.");
    XCTAssertNotNil(maybeValue, @"No value was given to cached data block.");
    XCTAssertFalse(cacheManager.wasCalledFromMainThread, @"Cache manager was called from main thread");
    XCTAssertFalse(cacheManager.revisionForIdentifierWasCalled, @"revisionForIdentifier was not called");
    XCTAssertFalse(cacheManager.cacheDataForIdentifierWithRevisionErrorWasCalled, @"cacheDataForIdentifierWithRevisionError was not called");
    XCTAssertTrue(cacheManager.cachedDataForIdentifierErrorWasCalled, @"cachedDataForIdentifierError was not called");
    XCTAssertFalse(cacheManager.removeCacheForIdentifierErrorWasCalled, @"removeCacheForIdentifierErrorWasCalled was called");
}

#pragma mark -

- (void)testPostProcessorChaining
{
    RKPostProcessorBlock postProcessor1 = ^RKPossibility *(RKPossibility *maybeData, RKURLRequestPromise *request) {
        return [maybeData refineValue:^RKPossibility *(NSString *value) {
            NSString *newValue = [value stringByAppendingString:@" fizz"];
            return [[RKPossibility alloc] initWithValue:newValue];
        }];
    };
    
    RKPostProcessorBlock postProcessor2 = ^RKPossibility *(RKPossibility *maybeData, RKURLRequestPromise *request) {
        return [maybeData refineValue:^RKPossibility *(NSString *value) {
            NSString *newValue = [value stringByAppendingString:@"buzz"];
            return [[RKPossibility alloc] initWithValue:newValue];
        }];
    };
    
    RKPostProcessorBlock postProcessor3 = RKPostProcessorBlockChain(postProcessor1, postProcessor2);
    RKPossibility *result = postProcessor3([[RKPossibility alloc] initWithValue:@"it should equal"], nil);
    XCTAssertEqual(result.state, kRKPossibilityStateValue, @"Unexpected state");
    XCTAssertEqualObjects(result.value, @"it should equal fizzbuzz", @"Unexpected value");
}

- (void)testJSONPostProcessor
{
    NSDictionary *goodTest = @{@"I like": @"cookies",
                               @"contains": @"potatoes",
                               @"array": @[ @1, @2, @3 ],
                               @"dictionary": @{@"a": @1, @"b": @2, @"c": @3},
                               @"null": [NSNull null]};
    
    NSData *goodTestData = [NSJSONSerialization dataWithJSONObject:goodTest options:0 error:NULL];
    RKPossibility *goodResult = kRKJSONPostProcessorBlock([[RKPossibility alloc] initWithValue:goodTestData], nil);
    XCTAssertEqual(goodResult.state, kRKPossibilityStateValue, @"Unexpected state");
    XCTAssertEqualObjects(goodResult.value, goodTest, @"Unexpected value");
    
    NSData *badTestData = [@"this is pure garbage" dataUsingEncoding:NSUTF8StringEncoding];
    RKPossibility *badResult = kRKJSONPostProcessorBlock([[RKPossibility alloc] initWithValue:badTestData], nil);
    XCTAssertEqual(badResult.state, kRKPossibilityStateError, @"Unexpected state");
    XCTAssertNotNil(badResult.error, @"Missing error");
}

- (void)testImagePostProcessor
{
    NSURL *goodTestLocation = [[NSBundle bundleForClass:[self class]] URLForImageResource:@"RKPostProcessorTestImage"];
    NSImage *goodTest = [[NSImage alloc] initWithContentsOfURL:goodTestLocation];
    XCTAssertNotNil(goodTest, @"Missing test image");
    
    NSData *goodTestData = NSImagePNGRepresentation(goodTest);
    RKPossibility *goodResult = kRKImagePostProcessorBlock([[RKPossibility alloc] initWithValue:goodTestData], nil);
    XCTAssertEqual(goodResult.state, kRKPossibilityStateValue, @"Unexpected state");
    XCTAssertNotNil(goodResult.value, @"Unexpected missing value");
    XCTAssertTrue(NSEqualSizes(goodTest.size, [goodResult.value size]), @"Size mismatch");
    
    NSData *badTestData = [@"this is most definitely not a valid image" dataUsingEncoding:NSUTF8StringEncoding];
    RKPossibility *badResult = kRKImagePostProcessorBlock([[RKPossibility alloc] initWithValue:badTestData], nil);
    XCTAssertEqual(badResult.state, kRKPossibilityStateError, @"Unexpected state");
    XCTAssertNotNil(badResult.error, @"Missing error");
}

@end