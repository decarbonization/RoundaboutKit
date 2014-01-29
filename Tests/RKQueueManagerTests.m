//
//  RKQueueManagerTests.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 1/29/14.
//  Copyright (c) 2014 Roundabout Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

static NSString *const kTestQueueName = @"com.roundabout.rk.tests.queue";

@interface RKQueueManagerTests : XCTestCase

@end

@implementation RKQueueManagerTests

- (void)testNamePersistence
{
    NSOperationQueue *testQueue = [RKQueueManager sharedQueueWithName:kTestQueueName];
    XCTAssertNotNil(testQueue, @"expected queue");
    XCTAssertEqualObjects([testQueue name], kTestQueueName, @"unexpected queue name");
    
    XCTAssertEqualObjects(testQueue, [RKQueueManager sharedQueueWithName:kTestQueueName], @"unexpected queue");
}

- (void)testCommonWorkQueuePersistence
{
    XCTAssertEqualObjects([RKQueueManager commonWorkQueue], [RKQueueManager commonWorkQueue], @"unexpected object inequality");
}

@end
