//
//  RKMockURLProtocol.h
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import <Foundation/Foundation.h>

@interface RKURLRequestStub : NSObject

#pragma mark - HTTP Version

+ (void)setHTTPVersionString:(NSString *)versionString;
+ (NSString *)HTTPVersionString;

#pragma mark - Outgoing

@property (nonatomic) NSURL *URL;
@property (nonatomic, copy) NSString *HTTPMethod;
@property (nonatomic, copy) NSDictionary *HTTPHeaders;
@property (nonatomic, copy) NSData *HTTPBody;

#pragma mark - Response Info

@property (nonatomic) NSHTTPURLResponse *response;
@property (nonatomic, copy) NSData *responseBody;

#pragma mark - Configuring the Response

- (void)andReturnData:(NSData *)data withHeaders:(NSDictionary *)headers andStatusCode:(NSInteger)statusCode;

#pragma mark -

- (void)andReturnString:(NSString *)string withHeaders:(NSDictionary *)headers andStatusCode:(NSInteger)statusCode;
- (void)andReturnJSON:(id)jsonObject withHeaders:(NSDictionary *)headers andStatusCode:(NSInteger)statusCode;
- (void)andReturnPlist:(id)plistObject withHeaders:(NSDictionary *)headers andStatusCode:(NSInteger)statusCode;

@end

#pragma mark -

@interface RKTestURLProtocol : NSURLProtocol

#pragma mark - Lifecycle

+ (void)setup;
+ (void)teardown;
+ (BOOL)isActive;

#pragma mark - Stubbing Requests

+ (void)addStub:(RKURLRequestStub *)request;
+ (void)removeStub:(RKURLRequestStub *)request;
+ (NSArray *)stubs;

#pragma mark -

+ (RKURLRequestStub *)stubGetRequestToURL:(NSURL *)url withHeaders:(NSDictionary *)headers;
+ (RKURLRequestStub *)stubDeleteRequestToURL:(NSURL *)url withHeaders:(NSDictionary *)headers;
+ (RKURLRequestStub *)stubPostRequestToURL:(NSURL *)url withHeaders:(NSDictionary *)headers andBody:(NSData *)body;
+ (RKURLRequestStub *)stubPutRequestToURL:(NSURL *)url withHeaders:(NSDictionary *)headers andBody:(NSData *)body;

@end
