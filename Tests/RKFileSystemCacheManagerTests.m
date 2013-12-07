//
//  RKCacheManagerTests.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import <XCTest/XCTest.h>
#import "RKFileSystemCacheManager.h"

static NSString *const kTestDataString = @"this is some lovely data you've got here";

static NSString *const kCacheIdentifier = @"MyLovelyArbitraryValue";
static NSString *const kRevision = @"1";

static NSString *const kNonExistentCacheIdentiifer = @"SmarchFifth";


@interface RKFileSystemCacheManagerTests : XCTestCase

@property RKFileSystemCacheManager *cacheManager;

@end

@implementation RKFileSystemCacheManagerTests

- (void)setUp
{
    [super setUp];
    
    self.cacheManager = [RKFileSystemCacheManager sharedCacheManager];
}

#pragma mark -

/* These tests must be run in the order in which they appear or they will not pass. */

- (void)test1StoringData
{
    NSData *testData = [kTestDataString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error = nil;
    BOOL success = [self.cacheManager cacheData:testData 
                                  forIdentifier:kCacheIdentifier
                                   withRevision:kRevision
                                          error:&error];
    XCTAssertTrue(success, @"could not store cache");
    XCTAssertNil(error, @"unexpected error");
}

- (void)test2RetrievingRevision
{
    NSString *revision = [self.cacheManager revisionForIdentifier:kCacheIdentifier];
    XCTAssertEqualObjects(revision, kRevision, @"unexpected revision");
}

- (void)test3RetrievingData
{
    NSError *error = nil;
    NSData *goodData = [self.cacheManager cachedDataForIdentifier:kCacheIdentifier error:&error];
    XCTAssertNotNil(goodData, @"could not retrieve data");
    XCTAssertNil(error, @"unexpected error");
    
    NSString *goodDataString = [[NSString alloc] initWithData:goodData encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(goodDataString, kTestDataString, @"unexpected value");
    
    
    NSData *badData = [self.cacheManager cachedDataForIdentifier:kNonExistentCacheIdentiifer error:&error];
    XCTAssertNil(badData, @"unexpected value");
    XCTAssertNil(error, @"unexpected error");
}

- (void)test4RemovingData
{
    NSError *error = nil;
    BOOL success = [self.cacheManager removeCacheForIdentifier:kCacheIdentifier error:&error];
    XCTAssertTrue(success, @"removing cache failed");
    XCTAssertNil(error, @"unexpected error");
    
    success = [self.cacheManager removeCacheForIdentifier:kNonExistentCacheIdentiifer error:&error];
    XCTAssertTrue(success, @"removing non-existent cache failed");
    XCTAssertNil(error, @"unexpected error");
}

- (void)test5RemovingAllData
{
    NSError *error = nil;
    BOOL success = [self.cacheManager removeAllCache:&error];
    XCTAssertTrue(success, @"could not teardown cache manager");
    XCTAssertNil(error, @"unexpected error");
    
    NSString *revision = [self.cacheManager revisionForIdentifier:kCacheIdentifier];
    XCTAssertNil(revision, @"unexpected revision");
    
    NSData *data = [self.cacheManager cachedDataForIdentifier:kCacheIdentifier error:&error];
    XCTAssertNil(data, @"unexpected data");
    XCTAssertNil(error, @"unexpected error");
}

@end
