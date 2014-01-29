//
//  RKImageLoaderTests.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 1/29/14.
//  Copyright (c) 2014 Roundabout Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RKMockPromise.h"

@interface RKImageLoaderTests : XCTestCase

@property (nonatomic) RKImageLoader *imageLoader;

@end

@implementation RKImageLoaderTests

- (void)setUp
{
    [super setUp];
    
    self.imageLoader = [RKImageLoader new];
    [self.imageLoader setValue:nil forKey:@"cacheManager"];
}

- (void)tearDown
{
    self.imageLoader = nil;
    
    [super tearDown];
}

- (RKMockPromise *)testPromise
{
    NSURL *imageDataLocation = [[NSBundle bundleForClass:[self class]] URLForImageResource:@"RKPostProcessorTestImage"];
    NSData *imageData = [NSData dataWithContentsOfURL:imageDataLocation];
    RKMockPromise *mockPromise = [[RKMockPromise alloc] initWithResult:[[RKPossibility alloc] initWithValue:imageData] duration:0.0];
    mockPromise.cacheIdentifier = @"abc123--test";
    [mockPromise addPostProcessor:[RKImagePostProcessor sharedPostProcessor]];
    return mockPromise;
}

#pragma mark -

- (void)testBasicLoading
{
    id imageView = [RKImageViewType new];
    
    __block BOOL success = NO;
    [self.imageLoader loadImagePromise:[self testPromise]
                           placeholder:nil
                              intoView:imageView
                     completionHandler:^(BOOL wasSuccessful) {
                         success = wasSuccessful;
                     }];
    [RunLoopHelper runFor:0.5];
    
    XCTAssertTrue(success, @"expected success");
    XCTAssertNotNil([imageView image], @"expected image");
}

- (void)testInMemoryCache
{
    id imageView = [RKImageViewType new];
    
    __block BOOL success = NO;
    [self.imageLoader loadImagePromise:[self testPromise]
                           placeholder:nil
                              intoView:imageView
                     completionHandler:^(BOOL wasSuccessful) {
                         success = wasSuccessful;
                     }];
    [RunLoopHelper runFor:0.5];
    
    XCTAssertTrue(success, @"expected success");
    XCTAssertNotNil([imageView image], @"expected image");
    
    
    RKMockPromise *testPromise = [self testPromise];
    [self.imageLoader loadImagePromise:testPromise
                           placeholder:nil
                              intoView:imageView
                     completionHandler:^(BOOL wasSuccessful) {
                         success = wasSuccessful;
                     }];
    [RunLoopHelper runFor:0.5];
    
    XCTAssertTrue(success, @"expected success");
    XCTAssertNotNil([imageView image], @"expected image");
    XCTAssertEqual(testPromise.state, kRKPromiseStateReady, @"unexpected realized promise");
}

- (void)testCanceling
{
    id imageView = [RKImageViewType new];
    
    RKMockPromise *testPromise = [self testPromise];
    testPromise.duration = 0.5;
    
    __block BOOL wasCalled = NO;
    [self.imageLoader loadImagePromise:testPromise
                           placeholder:nil
                              intoView:imageView
                     completionHandler:^(BOOL wasSuccessful) {
                         wasCalled = wasSuccessful;
                     }];
    [self.imageLoader stopLoadingImagesForView:imageView];
    [RunLoopHelper runFor:0.7];
    
    
    XCTAssertFalse(wasCalled, @"unexpected call through");
    XCTAssertNil([imageView image], @"unexpected image");
}

@end
