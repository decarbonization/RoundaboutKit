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
@property (nonatomic) RKRequestFactory *requestFactory;

@end

@implementation RKRequestFactoryTests

- (void)setUp
{
    [super setUp];
    
    self.postProcessor = [[RKSingleValuePostProcessor alloc] initWithObject:@42];
    self.mockReadCacheManager = [[RKMockURLRequestPromiseCacheManager alloc] initWithItems:@{}];
    self.mockWriteCacheManager = [[RKMockURLRequestPromiseCacheManager alloc] initWithItems:@{}];
    
    self.requestFactory = [[RKRequestFactory alloc] initWithBaseURL:[NSURL URLWithString:kBaseURLString]
                                                   readCacheManager:self.mockReadCacheManager
                                                  writeCacheManager:self.mockWriteCacheManager
                                                     postProcessors:@[ self.postProcessor ]];
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

@end
