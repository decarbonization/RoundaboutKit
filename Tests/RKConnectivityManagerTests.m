//
//  RKConnectivityManagerTests.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 1/29/14.
//  Copyright (c) 2014 Roundabout Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface RKConnectivityManagerTests : XCTestCase

@end

@implementation RKConnectivityManagerTests

- (void)setUp
{
    [super setUp];
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    [super tearDown];
}

#pragma mark -

- (void)testOnlineConnection
{
    RKConnectivityManager *manager = [[RKConnectivityManager alloc] initWithHostName:@"localhost"];
    XCTAssertEqual(manager.isConnected, YES, @"expected YES");
}

- (void)testOfflineConnection
{
    RKConnectivityManager *manager = [[RKConnectivityManager alloc] initWithHostName:@"this host will never be valid"];
    XCTAssertEqual(manager.isConnected, NO, @"expected NO");
}

@end
