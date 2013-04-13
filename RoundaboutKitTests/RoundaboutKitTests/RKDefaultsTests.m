//
//  RKDefaultsTests.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 4/12/13.
//
//

#import "RKDefaultsTests.h"

@implementation RKDefaultsTests

- (void)setUp
{
    [super setUp];
    
    [[NSUserDefaults standardUserDefaults] setPersistentDomain:@{} forName:@"com.roundabout.roundaboutkittests"];
}

- (void)tearDown
{
    [super tearDown];
    
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:@"com.roundabout.roundaboutkittests"];
}

#pragma mark Defaults Short-hand

- (void)testPersistentObject
{
    RKSetPersistentObject(@"PersistentObject", @"potatoes");
    STAssertEqualObjects(RKGetPersistentObject(@"PersistentObject"), @"potatoes", @"RK*PersistentObject is broken");
}

- (void)testPersistentInteger
{
    RKSetPersistentInteger(@"PersistentInteger", 42);
    STAssertEquals(RKGetPersistentInteger(@"PersistentInteger"), 42L, @"RK*PersistentInteger is broken");
}

- (void)testPersistentFloat
{
    RKSetPersistentFloat(@"PersistentFloat", 42.f);
    STAssertEquals(RKGetPersistentFloat(@"PersistentFloat"), 42.f, @"RK*PersistentFloat is broken");
}

- (void)testPersistentBool
{
    RKSetPersistentBool(@"PersistentBool", YES);
    STAssertEquals(RKGetPersistentBool(@"PersistentBool"), YES, @"RK*PersistentBOOL is broken");
}

#pragma mark -

- (void)testPersistentValueExists
{
    STAssertFalse(RKPersistentValueExists(@"TestDefault1"), @"RKPersistentValueExists returned wrong result");
    
    RKSetPersistentObject(@"TestDefault1", @"potatoes");
    
    STAssertTrue(RKPersistentValueExists(@"TestDefault1"), @"RKPersistentValueExists returned wrong result");
}

@end
