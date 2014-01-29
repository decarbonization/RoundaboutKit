//
//  RKRequestFactory.m
//  Pinna
//
//  Created by Kevin MacWhinnie on 5/31/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import "RKRequestFactory.h"
#import "RKURLRequestPromise.h"

@interface RKRequestFactory () {
    NSOperationQueue *_legacyRequestQueue;
}

#pragma mark - readwrite

@property (readwrite, RK_NONATOMIC_IOSONLY) NSURL *baseURL;
@property (readwrite, RK_NONATOMIC_IOSONLY) id <RKURLRequestPromiseCacheManager> readCacheManager;
@property (readwrite, RK_NONATOMIC_IOSONLY) id <RKURLRequestPromiseCacheManager> writeCacheManager;
@property (readwrite, RK_NONATOMIC_IOSONLY) NSOperationQueue *requestQueue;
@property (readwrite, copy, RK_NONATOMIC_IOSONLY) NSArray *postProcessors;

@end

#pragma mark -

@implementation RKRequestFactory

- (instancetype)initWithBaseURL:(NSURL *)baseURL
               readCacheManager:(id <RKURLRequestPromiseCacheManager>)readCacheManager
              writeCacheManager:(id <RKURLRequestPromiseCacheManager>)writeCacheManager
                 postProcessors:(NSArray *)postProcessors
{
    NSParameterAssert(baseURL);
    
    if((self = [super init])) {
        self.baseURL = baseURL;
        self.readCacheManager = readCacheManager;
        self.writeCacheManager = writeCacheManager;
        self.postProcessors = postProcessors;
        self.URLParameterStringifier = kRKURLParameterStringifierDefault;
    }
    
    return self;
}

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma mark - Dispensing URLs

- (NSURL *)URLWithPath:(NSString *)path parameters:(NSDictionary *)parameters
{
    NSParameterAssert(path);
    
    NSString *urlString = [path stringByStandardizingPath];
    if(parameters) {
        NSString *parameterString = RKDictionaryToURLParametersString(parameters);
        urlString = [urlString stringByAppendingFormat:@"?%@", parameterString];
    }
    
    return [NSURL URLWithString:urlString relativeToURL:self.baseURL];
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

- (NSData *)bodyForPayload:(id)body bodyType:(RKRequestFactoryBodyType)bodyType
{
    if(!body)
        return nil;
    
    switch (bodyType) {
        case kRKRequestFactoryBodyTypeData: {
            return body;
        }
            
        case kRKRequestFactoryBodyTypeURLParameters: {
            if(!self.URLParameterStringifier)
                [NSException raise:NSInternalInconsistencyException
                            format:@"Missing URLParameterStringifier."];
            
            return [RKDictionaryToURLParametersString(body, self.URLParameterStringifier) dataUsingEncoding:NSUTF8StringEncoding];
        }
            
        case kRKRequestFactoryBodyTypeJSON: {
            NSError *error = nil;
            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
            if(!JSONData)
                [NSException raise:NSInternalInconsistencyException format:@"Could not convert %@ to JSON. %@", body, error];
            
            return JSONData;
        }
            
    }
}

- (NSURLRequest *)POSTRequestWithPath:(NSString *)path parameters:(NSDictionary *)parameters body:(id)body bodyType:(RKRequestFactoryBodyType)bodyType
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self URLWithPath:path parameters:parameters]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[self bodyForPayload:body bodyType:bodyType]];
    return request;
}

- (NSURLRequest *)PUTRequestWithPath:(NSString *)path parameters:(NSDictionary *)parameters body:(id)body bodyType:(RKRequestFactoryBodyType)bodyType
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self URLWithPath:path parameters:parameters]];
    [request setHTTPMethod:@"PUT"];
    [request setHTTPBody:[self bodyForPayload:body bodyType:bodyType]];
    return request;
}

#pragma mark - Dispensing RKURLRequestPromises

- (RKURLRequestPromise *)requestPromiseWithRequest:(NSURLRequest *)request
{
    id <RKURLRequestPromiseCacheManager> cacheManager = nil;
    RKURLRequestPromiseOfflineBehavior offlineBehavior = kRKURLRequestPromiseOfflineBehaviorFail;
    if([request.HTTPMethod isEqualToString:@"GET"] && self.readCacheManager != nil) {
        cacheManager = self.readCacheManager;
        offlineBehavior = kRKURLRequestPromiseOfflineBehaviorUseCache;
    } else if(![request.HTTPMethod isEqualToString:@"DELETE"] && self.writeCacheManager != nil) {
        cacheManager = self.writeCacheManager;
        offlineBehavior = kRKURLRequestPromiseOfflineBehaviorUseCache;
    }
    
    RKURLRequestPromise *requestPromise = [[RKURLRequestPromise alloc] initWithRequest:request
                                                                       offlineBehavior:offlineBehavior
                                                                          cacheManager:cacheManager];
    [requestPromise addPostProcessors:RKCollectionDeepCopy(self.postProcessors)];
    requestPromise.authenticationHandler = self.authenticationHandler;
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

- (RKURLRequestPromise *)POSTRequestPromiseWithPath:(NSString *)path
                                         parameters:(NSDictionary *)parameters
                                               body:(id)body
                                           bodyType:(RKRequestFactoryBodyType)bodyType
{
    return [self requestPromiseWithRequest:[self POSTRequestWithPath:path parameters:parameters body:body bodyType:bodyType]];
}

- (RKURLRequestPromise *)PUTRequestPromiseWithPath:(NSString *)path
                                        parameters:(NSDictionary *)parameters
                                              body:(id)body
                                          bodyType:(RKRequestFactoryBodyType)bodyType
{
    return [self requestPromiseWithRequest:[self PUTRequestWithPath:path parameters:parameters body:body bodyType:bodyType]];
}

@end

#pragma mark -

@implementation RKRequestFactory (RKDeprecatedMethods)

- (id)initWithBaseURL:(NSURL *)baseURL
     readCacheManager:(id <RKURLRequestPromiseCacheManager>)readCacheManager
    writeCacheManager:(id <RKURLRequestPromiseCacheManager>)writeCacheManager
         requestQueue:(NSOperationQueue *)requestQueue
        postProcessor:(RKSimplePostProcessorBlock)postProcessor
{
    NSParameterAssert(baseURL);
    NSParameterAssert(requestQueue);
    
    NSArray *postProcessors = nil;
    if(postProcessor) {
        postProcessors = @[ [[RKSimplePostProcessor alloc] initWithBlock:postProcessor] ];
    }
    
    if((self = [self initWithBaseURL:baseURL
                    readCacheManager:readCacheManager
                   writeCacheManager:writeCacheManager
                      postProcessors:postProcessors])) {
        self.requestQueue = requestQueue;
    }
    
    return self;
}

- (RKSimplePostProcessorBlock)postProcessor
{
    if(self.postProcessors.count == 0)
        return nil;
    
    if(self.postProcessors.count != 1)
        [NSException raise:NSInternalInconsistencyException
                    format:@"%s called when %@ has more than one post-processor object.", __PRETTY_FUNCTION__, self];
    
    id postProcessor = self.postProcessors.firstObject;
    if(![postProcessor isKindOfClass:[RKSimplePostProcessor class]])
        [NSException raise:NSInternalInconsistencyException
                    format:@"%s called when active post-processor is not an RKSimplePostProcessor.", __PRETTY_FUNCTION__];
    
    return [(RKSimplePostProcessor *)postProcessor block];
}


- (void)setRequestQueue:(NSOperationQueue *)requestQueue
{
    _legacyRequestQueue = requestQueue;
}

- (NSOperationQueue *)requestQueue
{
    return _legacyRequestQueue;
}

@end
