    //
//  RKPreludeTests.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 4/12/13.
//
//

#import <XCTest/XCTest.h>

@interface RKPreludeTests : XCTestCase

@end

@implementation RKPreludeTests

- (void)testTime
{
    XCTAssertTrue(RK_TIME_MINUTE == 60.0, @"RK_TIME_MINUTE wrong value");
    XCTAssertTrue(RK_TIME_HOUR == 3600.0, @"RK_TIME_HOUR wrong value");
    XCTAssertTrue(RK_TIME_DAY == 86400, @"RK_TIME_DAY wrong value");
    XCTAssertTrue(RK_TIME_WEEK == 604800.0, @"RK_TIME_WEEK wrong value");
    XCTAssertTrue(kRKTimeIntervalInfinite == INFINITY, @"kRKTimeIntervalInfinite is not infinite");
    XCTAssertEqualObjects(RKMakeStringFromTimeInterval(150.0), @"2:30", @"RKMakeStringFromTimeInterval w/value returned wrong value");
    XCTAssertEqualObjects(RKMakeStringFromTimeInterval(-150.0), @"-:--", @"RKMakeStringFromTimeInterval w/negative value returned wrong value");
}

#pragma mark - Safe Casting

- (void)testCast
{
    XCTAssertThrows((void)RK_CAST_OR_THROW(NSArray, @"this should fail"), @"RK_CAST_OR_THROW failed to catch incompatibility between NSArray and NSString");
    XCTAssertNoThrow((void)RK_CAST_OR_THROW(NSString, [@"this should fail" mutableCopy]), @"RK_CAST_OR_THROW failed to match compatibility between NSString and NSMutableString");
}

- (void)testTryCast
{
    XCTAssertNil(RK_CAST_OR_NIL(NSArray, @"this should fail"), @"RK_CAST_OR_NIL failed to catch incompatibility between NSArray and NSString");
    XCTAssertNotNil(RK_CAST_OR_NIL(NSString, [@"this should fail" mutableCopy]), @"RK_CAST_OR_NIL failed to match compatibility between NSString and NSMutableString");
}

#pragma mark - Utilities

- (void)testSanitizeStringForSorting
{
    XCTAssertEqualObjects(RKSanitizeStringForSorting(@"The Beatles"), @"Beatles", @"RKSanitizeStringForSorting returned incorrect value");
    XCTAssertEqualObjects(RKSanitizeStringForSorting(@"the beatles"), @"beatles", @"RKSanitizeStringForSorting returned incorrect value");
    XCTAssertEqualObjects(RKSanitizeStringForSorting(@"Eagles"), @"Eagles", @"RKSanitizeStringForSorting returned incorrect value");
}

- (void)testGenerateIdentifierForStrings
{
    XCTAssertEqualObjects(RKGenerateIdentifierForStrings(@[@"first", @"Second", @"()[].,", @"THIRD"]), @"firstsecondthird", @"RKGenerateIdentifierForStrings returned incorrect value");
}

#pragma mark -

- (void)testStringGetMD5Hash
{
    NSString *hashedString = RKStringGetMD5Hash(@"test string");
    XCTAssertEqualObjects(hashedString, @"6f8db599de986fab7a21625b7916589c", @"Unexpected hash result");
}

- (void)testStringEscapeForInclusionInURL
{
    NSString *escapedString = RKStringEscapeForInclusionInURL(@"This is a lovely string :/?#[]@!$&'()*+,;=", NSUTF8StringEncoding);
    XCTAssertEqualObjects(escapedString, @"This%20is%20a%20lovely%20string%20%3A%2F%3F%23%5B%5D%40%21%24%26%27%28%29%2A%2B,%3B%3D", @"Unexpected escape result");
}

- (void)testDictionaryToURLParametersString
{
    NSDictionary *test = @{@"test": @"value"};
    
    NSString *result = RKDictionaryToURLParametersString(test, kRKURLParameterStringifierDefault);
    XCTAssertEqualObjects(result, @"test=value", @"Unexpected result");
}

@end
