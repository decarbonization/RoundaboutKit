//
//  RKRequestFactoryTests.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 1/29/14.
//  Copyright (c) 2014 Roundabout Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RKMockURLRequestPromiseCacheManager.h"

static NSString *const kBaseURLString = @"http://example.com";

@interface RKRequestFactoryTests : XCTestCase

@property (nonatomic) RKSingleValuePostProcessor *postProcessor;
@property (nonatomic) RKMockURLRequestPromiseCacheManager *mockReadCacheManager;
@property (nonatomic) RKMockURLRequestPromiseCacheManager *mockWriteCacheManager;
@property (nonatomic) id <RKURLRequestAuthenticationHandler> authenticationHandler;
@property (nonatomic) RKRequestFactory *requestFactory;

@end

@implementation RKRequestFactoryTests

- (void)setUp
{
    [super setUp];
    
    self.postProcessor = [[RKSingleValuePostProcessor alloc] initWithObject:@42];
    self.mockReadCacheManager = [[RKMockURLRequestPromiseCacheManager alloc] initWithItems:@{}];
    self.mockWriteCacheManager = [[RKMockURLRequestPromiseCacheManager alloc] initWithItems:@{}];
    self.authenticationHandler = (id <RKURLRequestAuthenticationHandler>)[NSObject new];
    
    self.requestFactory = [[RKRequestFactory alloc] initWithBaseURL:[NSURL URLWithString:kBaseURLString]
                                                   readCacheManager:self.mockReadCacheManager
                                                  writeCacheManager:self.mockWriteCacheManager
                                                     postProcessors:@[ self.postProcessor ]];
    self.requestFactory.authenticationHandler = self.authenticationHandler;
}

- (void)tearDown
{
    self.requestFactory = nil;
    self.postProcessor = nil;
    self.mockReadCacheManager = nil;
    self.mockWriteCacheManager = nil;
    
    [super tearDown];
}

#pragma mark -

- (void)testPropertyAssumptions
{
    XCTAssertEqualObjects(self.requestFactory.baseURL, [NSURL URLWithString:kBaseURLString], @"unexpected URL");
    XCTAssertEqualObjects(self.requestFactory.readCacheManager, self.mockReadCacheManager, @"unexpected read cache manager");
    XCTAssertEqualObjects(self.requestFactory.writeCacheManager, self.mockWriteCacheManager, @"unexpected write cache manager");
    XCTAssertEqualObjects(self.requestFactory.postProcessors, @[ self.postProcessor ], @"unexpected post processors");
}

- (void)testGeneratedURLs
{
    NSURL *noParameters = [self.requestFactory URLWithPath:@"/test" parameters:nil];
    XCTAssertEqualObjects([noParameters absoluteString], @"http://example.com/test", @"unexpected result");
    
    
    NSURL *withParameters = [self.requestFactory URLWithPath:@"/test" parameters:@{@"x": @1, @"y": @"2"}];
    XCTAssertEqualObjects([withParameters absoluteString], @"http://example.com/test?x=1&y=2", @"unexpected result");
}

- (void)testURLParameterStringifierIsUsed
{
    __block NSUInteger callCount = 0;
    RKURLParameterStringifier originalStringifier = self.requestFactory.URLParameterStringifier;
    RKURLParameterStringifier proxyStringifier = ^NSString *(id value) {
        callCount++;
        return originalStringifier(value);
    };
    
    self.requestFactory.URLParameterStringifier = proxyStringifier;
    (void)[self.requestFactory URLWithPath:@"/test" parameters:@{@"x": @1, @"y": @2}];
    XCTAssertEqual(callCount, (NSUInteger)2, @"wrong number of calls");
    self.requestFactory.URLParameterStringifier = originalStringifier;
}

#pragma mark - URL Requests

- (void)testGetURLRequest
{
    NSURLRequest *request = [self.requestFactory GETRequestWithPath:@"/test" parameters:@{@"one": @1}];
    
    XCTAssertEqualObjects([request.URL absoluteString], @"http://example.com/test?one=1", @"unexpected URL");
    XCTAssertEqualObjects(request.HTTPMethod, @"GET", @"unexpected HTTP method");
    XCTAssertNil(request.HTTPBody, @"unexpected HTTP body");
    XCTAssertNil(request.HTTPBodyStream, @"unexpected HTTP body stream");
}

- (void)testDeleteURLRequest
{
    NSURLRequest *request = [self.requestFactory DELETERequestWithPath:@"/test" parameters:@{@"one": @1}];
    
    XCTAssertEqualObjects([request.URL absoluteString], @"http://example.com/test?one=1", @"unexpected URL");
    XCTAssertEqualObjects(request.HTTPMethod, @"DELETE", @"unexpected HTTP method");
    XCTAssertNil(request.HTTPBody, @"unexpected HTTP body");
    XCTAssertNil(request.HTTPBodyStream, @"unexpected HTTP body stream");
}

#pragma mark -

- (void)testPostURLRequestWithURLParameters
{
    NSURLRequest *request = [self.requestFactory POSTRequestWithPath:@"/test"
                                                          parameters:@{@"one": @1}
                                                                body:@{@"two": @2}
                                                            bodyType:kRKRequestFactoryBodyTypeURLParameters];
    
    XCTAssertEqualObjects([request.URL absoluteString], @"http://example.com/test?one=1", @"unexpected URL");
    XCTAssertEqualObjects(request.HTTPMethod, @"POST", @"unexpected HTTP method");
    XCTAssertNotNil(request.HTTPBody, @"missing HTTP body");
    XCTAssertEqualObjects(request.HTTPBody, [@"two=2" dataUsingEncoding:NSUTF8StringEncoding], @"unexpected HTTP body");
    XCTAssertNil(request.HTTPBodyStream, @"unexpected HTTP body stream");
}

- (void)testPostURLRequestWithJSON
{
    NSURLRequest *request = [self.requestFactory POSTRequestWithPath:@"/test"
                                                          parameters:@{@"one": @1}
                                                                body:@{@"two": @2}
                                                            bodyType:kRKRequestFactoryBodyTypeJSON];
    
    XCTAssertEqualObjects([request.URL absoluteString], @"http://example.com/test?one=1", @"unexpected URL");
    XCTAssertEqualObjects(request.HTTPMethod, @"POST", @"unexpected HTTP method");
    XCTAssertNotNil(request.HTTPBody, @"missing HTTP body");
    XCTAssertEqualObjects(request.HTTPBody, [@"{\"two\":2}" dataUsingEncoding:NSUTF8StringEncoding], @"unexpected HTTP body");
    XCTAssertNil(request.HTTPBodyStream, @"unexpected HTTP body stream");
}

- (void)testPostURLRequestWithData
{
    NSURLRequest *request = [self.requestFactory POSTRequestWithPath:@"/test"
                                                          parameters:@{@"one": @1}
                                                                body:[@"testy test test" dataUsingEncoding:NSUTF8StringEncoding]
                                                            bodyType:kRKRequestFactoryBodyTypeData];
    
    XCTAssertEqualObjects([request.URL absoluteString], @"http://example.com/test?one=1", @"unexpected URL");
    XCTAssertEqualObjects(request.HTTPMethod, @"POST", @"unexpected HTTP method");
    XCTAssertNotNil(request.HTTPBody, @"missing HTTP body");
    XCTAssertEqualObjects(request.HTTPBody, [@"testy test test" dataUsingEncoding:NSUTF8StringEncoding], @"unexpected HTTP body");
    XCTAssertNil(request.HTTPBodyStream, @"unexpected HTTP body stream");
}

#pragma mark -

- (void)testPutURLRequestWithURLParameters
{
    NSURLRequest *request = [self.requestFactory PUTRequestWithPath:@"/test"
                                                         parameters:@{@"one": @1}
                                                               body:@{@"two": @2}
                                                           bodyType:kRKRequestFactoryBodyTypeURLParameters];
    
    XCTAssertEqualObjects([request.URL absoluteString], @"http://example.com/test?one=1", @"unexpected URL");
    XCTAssertEqualObjects(request.HTTPMethod, @"PUT", @"unexpected HTTP method");
    XCTAssertNotNil(request.HTTPBody, @"missing HTTP body");
    XCTAssertEqualObjects(request.HTTPBody, [@"two=2" dataUsingEncoding:NSUTF8StringEncoding], @"unexpected HTTP body");
    XCTAssertNil(request.HTTPBodyStream, @"unexpected HTTP body stream");
}

- (void)testPutURLRequestWithJSON
{
    NSURLRequest *request = [self.requestFactory PUTRequestWithPath:@"/test"
                                                         parameters:@{@"one": @1}
                                                               body:@{@"two": @2}
                                                           bodyType:kRKRequestFactoryBodyTypeJSON];
    
    XCTAssertEqualObjects([request.URL absoluteString], @"http://example.com/test?one=1", @"unexpected URL");
    XCTAssertEqualObjects(request.HTTPMethod, @"PUT", @"unexpected HTTP method");
    XCTAssertNotNil(request.HTTPBody, @"missing HTTP body");
    XCTAssertEqualObjects(request.HTTPBody, [@"{\"two\":2}" dataUsingEncoding:NSUTF8StringEncoding], @"unexpected HTTP body");
    XCTAssertNil(request.HTTPBodyStream, @"unexpected HTTP body stream");
}

- (void)testPutURLRequestWithData
{
    NSURLRequest *request = [self.requestFactory PUTRequestWithPath:@"/test"
                                                         parameters:@{@"one": @1}
                                                               body:[@"testy test test" dataUsingEncoding:NSUTF8StringEncoding]
                                                           bodyType:kRKRequestFactoryBodyTypeData];
    
    XCTAssertEqualObjects([request.URL absoluteString], @"http://example.com/test?one=1", @"unexpected URL");
    XCTAssertEqualObjects(request.HTTPMethod, @"PUT", @"unexpected HTTP method");
    XCTAssertNotNil(request.HTTPBody, @"missing HTTP body");
    XCTAssertEqualObjects(request.HTTPBody, [@"testy test test" dataUsingEncoding:NSUTF8StringEncoding], @"unexpected HTTP body");
    XCTAssertNil(request.HTTPBodyStream, @"unexpected HTTP body stream");
}

#pragma mark - Request Promises

- (void)testReadRequestPromise
{
    RKURLRequestPromise *requestPromise = [self.requestFactory GETRequestPromiseWithPath:@"/test" parameters:@{@"one": @1}];
    XCTAssertEqualObjects(requestPromise.cacheManager, self.mockReadCacheManager, @"unexpected cache manager");
    XCTAssertEqualObjects(requestPromise.authenticationHandler, self.authenticationHandler, @"unexpected authentication handler");
    XCTAssertEqualObjects(requestPromise.postProcessors, @[ self.postProcessor ], @"unexpected post processors");
}

- (void)testWriteRequestPromise
{
    RKURLRequestPromise *requestPromise = [self.requestFactory POSTRequestPromiseWithPath:@"/test"
                                                                               parameters:@{@"one": @1}
                                                                                     body:@{}
                                                                                 bodyType:kRKRequestFactoryBodyTypeURLParameters];
    XCTAssertEqualObjects(requestPromise.cacheManager, self.mockWriteCacheManager, @"unexpected cache manager");
    XCTAssertEqualObjects(requestPromise.authenticationHandler, self.authenticationHandler, @"unexpected authentication handler");
    XCTAssertEqualObjects(requestPromise.postProcessors, @[ self.postProcessor ], @"unexpected post processors");
}

- (void)testDeleteRequestPromise
{
    RKURLRequestPromise *requestPromise = [self.requestFactory DELETERequestPromiseWithPath:@"/test" parameters:@{@"one": @1}];
    XCTAssertNil(requestPromise.cacheManager, @"unexpected cache manager");
    XCTAssertEqualObjects(requestPromise.authenticationHandler, self.authenticationHandler, @"unexpected authentication handler");
    XCTAssertEqualObjects(requestPromise.postProcessors, @[ self.postProcessor ], @"unexpected post processors");
}

@end
