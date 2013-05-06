//
//  RKURLRequestPromiseTests.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import "RKURLRequestPromiseTests.h"
#import "RKMockURLProtocol.h"

@interface RKURLRequestPromiseTests ()

@property (copy) NSArray *URLs;

@end

@implementation RKURLRequestPromiseTests

- (NSArray *)predeterminedResponses
{
    NSURL *predeterminedResponsesLocation = [[NSBundle bundleForClass:[self class]] URLForResource:@"PredeterminedResponses" withExtension:@"plist"];
    return [NSArray arrayWithContentsOfURL:predeterminedResponsesLocation];
}

- (void)registerPredeterminedResponses
{
    for (NSDictionary *predeterminedResponse in [self predeterminedResponses]) {
        NSURL *url = [NSURL URLWithString:predeterminedResponse[@"URL"]];
        NSString *method = predeterminedResponse[@"method"];
        NSInteger statusCode = [predeterminedResponse[@"statusCode"] integerValue];
        NSDictionary *headers = predeterminedResponse[@"headers"];
        NSData *response = [predeterminedResponse[@"responseString"] dataUsingEncoding:NSUTF8StringEncoding];
        
        [RKMockURLProtocol on:url
                   withMethod:method
              yieldStatusCode:statusCode
                      headers:headers
                         data:response];
    }
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
