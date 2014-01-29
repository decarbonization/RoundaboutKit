//
//  RKPersisterTests.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 1/29/14.
//  Copyright (c) 2014 Roundabout Software, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RunLoopHelper.h"

static NSTimeInterval const kRunLoopDuration = 1.0;

@interface RKPersisterTests : XCTestCase

@property (nonatomic) NSURL *contentsLocation;
@property (nonatomic) NSOperationQueue *notificationDeliveryQueue;
@property (nonatomic) RKPersister *persister;

@end

@implementation RKPersisterTests

- (void)setUp
{
    [super setUp];
    
    self.contentsLocation = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingString:[[NSUUID UUID] UUIDString]]];
    
    NSDictionary *testContents = @{@"LastModified": [NSDate dateWithTimeIntervalSince1970:0],
                                   @"Contents": @"hello, world!"};
    [[NSKeyedArchiver archivedDataWithRootObject:testContents] writeToURL:self.contentsLocation options:kNilOptions error:NULL];
    
    self.notificationDeliveryQueue = [NSOperationQueue new];
    self.persister = [[RKPersister alloc] initWithLocation:self.contentsLocation loadImmediately:NO respondsToMemoryPressure:YES];
}

- (void)tearDown
{
    [self.persister remove:NULL];
    
    [super tearDown];
}

#pragma mark -

- (void)testLoadingWithNoExistingContents
{
    [[NSFileManager defaultManager] removeItemAtURL:self.contentsLocation error:NULL];
    
    
    __block BOOL loadedNotificationDelivered = NO;
    [[NSNotificationCenter defaultCenter] addObserverForName:RKPersisterDidLoadNotification object:self.persister queue:self.notificationDeliveryQueue usingBlock:^(NSNotification *note) {
        loadedNotificationDelivered = YES;
    }];
    
    [self.persister reloadContentsAsynchronously];
    [RunLoopHelper runFor:kRunLoopDuration];
    
    XCTAssertTrue(loadedNotificationDelivered, @"loaded notification was not delievered");
    XCTAssertNil(self.persister.lastModified, @"unexpected last modified date");
    XCTAssertNil(self.persister.contents, @"unexpected value");
}

- (void)testLoadingWithExistingContents
{
    __block BOOL loadedNotificationDelivered = NO;
    [[NSNotificationCenter defaultCenter] addObserverForName:RKPersisterDidLoadNotification object:self.persister queue:self.notificationDeliveryQueue usingBlock:^(NSNotification *note) {
        loadedNotificationDelivered = YES;
    }];
    
    [self.persister reloadContentsAsynchronously];
    [RunLoopHelper runFor:kRunLoopDuration];
    
    XCTAssertTrue(loadedNotificationDelivered, @"loaded notification was not delievered");
    XCTAssertEqualObjects(self.persister.lastModified, [NSDate dateWithTimeIntervalSince1970:0], @"unexpected last modified date");
    XCTAssertEqualObjects(self.persister.contents, @"hello, world!", @"unexpected value");
}

#pragma mark -

- (void)testSaving
{
    __block BOOL saveNotificationDelivered = NO;
    [[NSNotificationCenter defaultCenter] addObserverForName:RKPersisterDidSaveNotification object:self.persister queue:self.notificationDeliveryQueue usingBlock:^(NSNotification *note) {
        saveNotificationDelivered = YES;
    }];
    
    __block BOOL saveDidFailNotificationDelivered = NO;
    [[NSNotificationCenter defaultCenter] addObserverForName:RKPersisterDidFailToSaveNotification object:self.persister queue:self.notificationDeliveryQueue usingBlock:^(NSNotification *note) {
        saveDidFailNotificationDelivered = YES;
    }];
    
    __block BOOL didSave = NO;
    [self.persister setContents:@"¡hola, mundo!" saveCompletionHandler:^(BOOL success, NSError *error) {
        didSave = success;
    }];
    [RunLoopHelper runFor:kRunLoopDuration];
    
    XCTAssertTrue(saveNotificationDelivered, @"expected save notification");
    XCTAssertFalse(saveDidFailNotificationDelivered, @"unexpected save did fail notification");
    XCTAssertTrue(didSave, @"expected successful save");
    XCTAssertNotNil(self.persister.lastModified, @"expected date");
    XCTAssertEqualObjects([self.persister contents], @"¡hola, mundo!", @"unexpected value");
}

#pragma mark -

- (void)testUnloading
{
    __block BOOL unloadNotificationDelivered = NO;
    [[NSNotificationCenter defaultCenter] addObserverForName:RKPersisterDidUnloadNotification object:self.persister queue:self.notificationDeliveryQueue usingBlock:^(NSNotification *note) {
        unloadNotificationDelivered = YES;
    }];
    
    XCTAssertTrue([self.persister unload], @"expected to unload successfully");
    XCTAssertTrue(unloadNotificationDelivered, @"expected unload notification");
    XCTAssertNil(self.persister.contents, @"unexpected contents");
}

- (void)testRemoval
{
    NSError *error = nil;
    XCTAssertTrue([self.persister remove:&error], @"removal failed");
    XCTAssertNil(error, @"unexpected error");
}

@end
