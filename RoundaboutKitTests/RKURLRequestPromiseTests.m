//
//  RKURLRequestPromiseTests.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import "RKURLRequestPromiseTests.h"
#import "RKMockURLProtocol.h"

@implementation RKURLRequestPromiseTests

- (void)registerPredeterminedResponses
{
    
}

- (void)setUp
{
    [super setUp];
    
    [self registerPredeterminedResponses];
}

- (void)tearDown
{
    [super tearDown];
    
    [RKMockURLProtocol removeAllRoutes];
}

@end
