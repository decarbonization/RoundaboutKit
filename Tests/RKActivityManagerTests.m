//
//  RKActivityManagerTests.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 4/12/13.
//
//

#import <XCTest/XCTest.h>

@interface RKActivityManagerTests : XCTestCase

@end

@implementation RKActivityManagerTests

- (void)setUp
{
    [super setUp];
    
}

- (void)tearDown
{
    [super tearDown];
    
}

- (void)testActivityManager
{
    RKActivityManager *activityManager = [RKActivityManager sharedActivityManager];
    
    XCTAssertFalse(activityManager.isActive, @".isActive is wrong");
    XCTAssertEqual(activityManager.activityCount, 0UL, @".activityCount is wrong");
    
    [activityManager incrementActivityCount];
    [activityManager incrementActivityCount];
    
    XCTAssertTrue(activityManager.isActive, @".isActive is wrong");
    XCTAssertEqual(activityManager.activityCount, 2UL, @".activityCount is wrong");
    
    [activityManager decrementActivityCount];
    [activityManager decrementActivityCount];
    
    XCTAssertFalse(activityManager.isActive, @".isActive is wrong");
    XCTAssertEqual(activityManager.activityCount, 0UL, @".activityCount is wrong");
    
    [activityManager decrementActivityCount];
    
    XCTAssertEqual(activityManager.activityCount, 0UL, @".activityCount is wrong");
}

@end
