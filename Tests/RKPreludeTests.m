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

@implementation RKPreludeTests {
    NSArray *_pregeneratedArray;
    NSDictionary *_pregeneratedDictionary;
}

- (void)setUp
{
    [super setUp];
    
    _pregeneratedArray = @[ @"1", @"2", @"3", @"4", @"5" ];
    _pregeneratedDictionary = @{
        @"test1": @{@"leaf1": @[]},
        @"test2": [NSNull null],
        @"test3": @[]
    };
}

- (void)tearDown
{
    [super tearDown];
}

#pragma mark -

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

#pragma mark - Collection Operations
#pragma mark - • Generation

- (void)testCollectionGeneration
{
    NSArray *generatedArray = RKCollectionGenerateArray(5, ^id(NSUInteger index) {
        return [NSString stringWithFormat:@"%ld", index + 1];
    });
    XCTAssertEqualObjects(generatedArray, _pregeneratedArray, @"RKCollectionGenerateArray returned incorrect value");
}

#pragma mark - • Mapping

- (void)testCollectionMapToArray
{
    NSArray *mappedArray = RKCollectionMapToArray(_pregeneratedArray, ^id(NSString *value) {
        return [value stringByAppendingString:@"0"];
    });
    NSArray *expectedArray = @[ @"10", @"20", @"30", @"40", @"50" ];
    XCTAssertEqualObjects(mappedArray, expectedArray, @"RKCollectionMapToArray returned incorrect value");
}

- (void)testCollectionMapToMutableArray
{
    NSMutableArray *mappedArray = RKCollectionMapToMutableArray(_pregeneratedArray, ^id(NSString *value) {
        return [value stringByAppendingString:@"0"];
    });
    NSArray *expectedArray = @[ @"10", @"20", @"30", @"40", @"50" ];
    XCTAssertEqualObjects(mappedArray, expectedArray, @"RKCollectionMapToMutableArray returned incorrect value");
    
    XCTAssertNoThrow([mappedArray addObject:@"60"], @"RKCollectionMapToMutableArray returned non-mutable array");
}

- (void)testCollectionMapToOrderedSet
{
    NSOrderedSet *mappedOrderedSet = RKCollectionMapToOrderedSet(_pregeneratedArray, ^id(NSString *value) {
        return [value stringByAppendingString:@"0"];
    });
    NSOrderedSet *expectedOrderedSet = [NSOrderedSet orderedSetWithObjects:@"10", @"20", @"30", @"40", @"50", nil];
    XCTAssertEqualObjects(mappedOrderedSet, expectedOrderedSet, @"RKCollectionMapToOrderedSet returned incorrect value");
}

#pragma mark - • Filtering

- (void)testFilterToArray
{
    NSArray *filteredArray = RKCollectionFilterToArray(_pregeneratedArray, ^BOOL(NSString *value) {
        return ([value integerValue] % 2 == 0);
    });
    NSArray *expectedArray = @[ @"2", @"4" ];
    XCTAssertEqualObjects(filteredArray, expectedArray, @"RKCollectionFilterToArray returned incorrect value");
}

#pragma mark - • Matching

- (void)testDoesAnyValueMatch
{
    BOOL doesAnyValueMatch = RKCollectionDoesAnyValueMatch(_pregeneratedArray, ^BOOL(NSString *value) {
        return [value isEqualToString:@"3"];
    });
    XCTAssertTrue(doesAnyValueMatch, @"RKCollectionDoesAnyValueMatch returned incorrect value");
}

- (void)testDoAllValuesMatch
{
    BOOL doAllValuesMatch = RKCollectionDoAllValuesMatch(_pregeneratedArray, ^BOOL(NSString *value) {
        return [value integerValue] != 0;
    });
    XCTAssertTrue(doAllValuesMatch, @"RKCollectionDoAllValuesMatch returned incorrect value");
}

- (void)testFindFirstMatch
{
    NSString *firstMatch = RKCollectionFindFirstMatch(_pregeneratedArray, ^BOOL(NSString *value) {
        return [value isEqualToString:@"3"];
    });
    
    XCTAssertEqualObjects(firstMatch, @"3", @"RKCollectionFindFirstMatch returned incorrect value");
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

- (void)testFilterOutNSNull
{
    XCTAssertNil(RKFilterOutNSNull([NSNull null]), @"RKFilterOutNSNull didn't filter out NSNull");
}

- (void)testJSONDictionaryGetObjectAtKeyPath
{
    XCTAssertEqualObjects(RKJSONDictionaryGetObjectAtKeyPath(_pregeneratedDictionary, @"test1.leaf1"), @[], @"RKJSONDictionaryGetObjectAtKeyPath not indexing correctly");
    XCTAssertNil(RKJSONDictionaryGetObjectAtKeyPath(_pregeneratedDictionary, @"test2.leaf2"), @"RKJSONDictionaryGetObjectAtKeyPath not indexing correctly");
    XCTAssertEqualObjects(RKJSONDictionaryGetObjectAtKeyPath(_pregeneratedDictionary, @"test3"), @[], @"RKJSONDictionaryGetObjectAtKeyPath not indexing correctly");
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
