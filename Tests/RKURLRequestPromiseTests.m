//
//  RKURLRequestPromiseTests.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import <XCTest/XCTest.h>
#import "RKTestURLProtocol.h"
#import "RKMockURLRequestPromiseCacheManager.h"

#define PLAIN_TEXT_URL_STRING   @"http://test/plaintext"
#define PLAIN_TEXT_STRING       (@"hello, world!")


@interface RKURLRequestPromiseTests : XCTestCase

@property RKConnectivityManager *connectivityManager;

@end

@implementation RKURLRequestPromiseTests

- (void)setUp
{
    [super setUp];
    
    self.connectivityManager = [[RKConnectivityManager alloc] initWithHostName:@"localhost"];
    [RKTestURLProtocol setup];
    
    RKTestURLRequestStub *stub = [RKTestURLProtocol stubGetRequestToURL:[NSURL URLWithString:PLAIN_TEXT_URL_STRING]
                                                        withHeaders:nil];
    [stub andReturnString:PLAIN_TEXT_STRING
              withHeaders:@{@"Etag": @"SomeArbitraryValue"}
            andStatusCode:200];
}

- (void)tearDown
{
    [super tearDown];
    
    [RKTestURLProtocol teardown];
}

#pragma mark -

- (RKURLRequestPromise *)makePlainTextWithNoCacheRequest
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:PLAIN_TEXT_URL_STRING]];
    RKURLRequestPromise *testPromise = [[RKURLRequestPromise alloc] initWithRequest:request
                                                                    offlineBehavior:kRKURLRequestPromiseOfflineBehaviorFail
                                                                       cacheManager:nil];
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

- (void)testPostProcessorAssumptions
{
    RKURLRequestPromise *testPromise = [self makePlainTextWithNoCacheRequest];
    
    __block BOOL hadPossibility = NO;
    __block BOOL hadSecondaryThread = NO;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    testPromise.postProcessor = ^RKPossibility *(RKPossibility *maybeData, RKURLRequestPromise *request) {
        hadPossibility = (maybeData != nil);
        hadSecondaryThread = ![NSThread isMainThread];
        
        return maybeData;
    };
#pragma clang diagnostic pop
    
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
                                                                    offlineBehavior:kRKURLRequestPromiseOfflineBehaviorFail
                                                                       cacheManager:cacheManager];
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
                                                                    offlineBehavior:kRKURLRequestPromiseOfflineBehaviorFail
                                                                       cacheManager:cacheManager];
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
                                                                    offlineBehavior:kRKURLRequestPromiseOfflineBehaviorFail
                                                                       cacheManager:cacheManager];
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

- (void)testCacheManagerAssumptionsAboutOfflineSuccess
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
                                                                    offlineBehavior:kRKURLRequestPromiseOfflineBehaviorUseCacheIfAvailable
                                                                       cacheManager:cacheManager];
    testPromise.cacheIdentifier = kCacheIdentifier;
    testPromise.connectivityManager = [[RKConnectivityManager alloc] initWithHostName:PLAIN_TEXT_URL_STRING];
    
    NSError *error = nil;
    NSData *result = [testPromise waitForRealization:&error];
    XCTAssertNotNil(result, @"Success value is missing");
    XCTAssertNil(error, @"RKAwait unexpectedly errored");
    XCTAssertFalse(cacheManager.removeCacheForIdentifierErrorWasCalled, @"removeCacheForIdentifierErrorWasCalled was called");
    XCTAssertFalse(cacheManager.wasCalledFromMainThread, @"Cache manager was called from main thread");
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
                                                                    offlineBehavior:kRKURLRequestPromiseOfflineBehaviorFail
                                                                       cacheManager:cacheManager];
    testPromise.cacheIdentifier = kCacheIdentifier;
    testPromise.connectivityManager = self.connectivityManager;
    
    NSError *error = nil;
    id value = [[testPromise cachedData] waitForRealization:&error];
    XCTAssertNotNil(value, @"value missing");
    XCTAssertNil(error, @"unexpected error");
}

#pragma mark -

- (void)testStateConsistencyGuards
{
    RKURLRequestPromise *request = [self makePlainTextWithNoCacheRequest];
    XCTAssertThrows([request setConnectivityManager:nil], @"expected `-setConnectivityManager:` to throw.");
}

#pragma mark - Legacy Post-Processors

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

- (void)testPostProcessorChaining
{
    RKSimplePostProcessorBlock postProcessor1 = ^RKPossibility *(RKPossibility *maybeData, RKURLRequestPromise *request) {
        return [maybeData refineValue:^RKPossibility *(NSString *value) {
            NSString *newValue = [value stringByAppendingString:@" fizz"];
            return [[RKPossibility alloc] initWithValue:newValue];
        }];
    };
    
    RKSimplePostProcessorBlock postProcessor2 = ^RKPossibility *(RKPossibility *maybeData, RKURLRequestPromise *request) {
        return [maybeData refineValue:^RKPossibility *(NSString *value) {
            NSString *newValue = [value stringByAppendingString:@"buzz"];
            return [[RKPossibility alloc] initWithValue:newValue];
        }];
    };
    
    RKSimplePostProcessorBlock postProcessor3 = RKPostProcessorBlockChain(postProcessor1, postProcessor2);
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

#pragma clang diagnostic pop

@end
