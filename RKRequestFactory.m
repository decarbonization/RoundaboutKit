//
//  RKRequestFactory.m
//  Pinna
//
//  Created by Kevin MacWhinnie on 5/31/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import "RKRequestFactory.h"
#import "RKPrelude.h"

@interface RKRequestFactory ()

@property (readwrite, RK_NONATOMIC_IOSONLY) NSURL *baseURL;
@property (readwrite, RK_NONATOMIC_IOSONLY) id <RKURLRequestPromiseCacheManager> cacheManager;
@property (readwrite, RK_NONATOMIC_IOSONLY) NSOperationQueue *requestQueue;
@property (readwrite, copy, RK_NONATOMIC_IOSONLY) RKPostProcessorBlock postProcessor;

@end

@implementation RKRequestFactory

- (id)initWithBaseURL:(NSURL *)baseURL
         cacheManager:(id <RKURLRequestPromiseCacheManager>)cacheManager
         requestQueue:(NSOperationQueue *)requestQueue
        postProcessor:(RKPostProcessorBlock)postProcessor
{
    NSParameterAssert(baseURL);
    NSParameterAssert(requestQueue);
    
    if((self = [super init])) {
        self.baseURL = baseURL;
        self.cacheManager = cacheManager;
        self.requestQueue = requestQueue;
        self.postProcessor = postProcessor;
    }
    
    return self;
}

#pragma mark - Dispensing URLs

- (NSURL *)URLWithPath:(NSString *)path parameters:(NSDictionary *)parameters
{
    NSParameterAssert(path);
    
    NSMutableString *urlString = [[self.baseURL absoluteString] mutableCopy];
    if(![urlString hasSuffix:@"/"] && ![path hasPrefix:@"/"])
        [urlString appendString:@"/"];
    
    if([urlString hasSuffix:@"/"] && [path hasPrefix:@"/"])
        [urlString deleteCharactersInRange:NSMakeRange(urlString.length - 1, 1)];
    
    [urlString appendString:path];
    
    if(parameters) {
        NSString *parameterString = RKDictionaryToURLParametersString(parameters);
        [urlString appendFormat:@"?%@", parameterString];
    }
    
    return [NSURL URLWithString:urlString];
}

#pragma mark - Dispensing NSURLRequests

- (NSURLRequest *)GETRequestWithPath:(NSString *)path parameters:(NSDictionary *)parameters
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self URLWithPath:path parameters:parameters]];
    [request setHTTPMethod:@"GET"];
    return request;
}

- (NSURLRequest *)DELETERequestWithPath:(NSString *)path parameters:(NSDictionary *)parameters
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self URLWithPath:path parameters:parameters]];
    [request setHTTPMethod:@"DELETE"];
    return request;
}

#pragma mark -

- (NSData *)bodyForPayload:(id)payload
{
    if(!payload)
        return nil;
    
    NSData *data = RK_TRY_CAST(NSData, payload);
    if(!data) {
        NSError *error = nil;
        data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
        if(!data)
            [NSException raise:NSInternalInconsistencyException format:@"Could not convert %@ to JSON. %@", payload, error];
    }
    
    return data;
}

- (NSURLRequest *)POSTRequestWithPath:(NSString *)path parameters:(NSDictionary *)parameters payload:(id)payload
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self URLWithPath:path parameters:parameters]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[self bodyForPayload:payload]];
    return request;
}

- (NSURLRequest *)PUTRequestWithPath:(NSString *)path parameters:(NSDictionary *)parameters payload:(id)payload
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self URLWithPath:path parameters:parameters]];
    [request setHTTPMethod:@"PUT"];
    [request setHTTPBody:[self bodyForPayload:payload]];
    return request;
}

#pragma mark - Dispensing RKURLRequestPromises

- (RKURLRequestPromise *)requestPromiseWithRequest:(NSURLRequest *)request
{
    RKURLRequestPromise *requestPromise = [[RKURLRequestPromise alloc] initWithRequest:request
                                                                          cacheManager:self.cacheManager
                                                                          requestQueue:self.requestQueue];
    requestPromise.postProcessor = self.postProcessor;
    return requestPromise;
}

#pragma mark -

- (RKURLRequestPromise *)GETRequestPromiseWithPath:(NSString *)path parameters:(NSDictionary *)parameters
{
    return [self requestPromiseWithRequest:[self GETRequestWithPath:path parameters:parameters]];
}

- (RKURLRequestPromise *)DELETERequestPromiseWithPath:(NSString *)path parameters:(NSDictionary *)parameters
{
    return [self requestPromiseWithRequest:[self DELETERequestWithPath:path parameters:parameters]];
}

#pragma mark -

- (RKURLRequestPromise *)POSTRequestPromiseWithPath:(NSString *)path parameters:(NSDictionary *)parameters payload:(id)payload
{
    return [self requestPromiseWithRequest:[self POSTRequestWithPath:path parameters:parameters payload:payload]];
}

- (RKURLRequestPromise *)PUTRequestPromiseWithPath:(NSString *)path parameters:(NSDictionary *)parameters payload:(id)payload
{
    return [self requestPromiseWithRequest:[self PUTRequestWithPath:path parameters:parameters payload:payload]];
}

@end
