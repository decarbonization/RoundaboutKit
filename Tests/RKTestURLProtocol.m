//
//  RKMockURLProtocol.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import "RKTestURLProtocol.h"

NSString *const RKRequestNotAllowedException = @"RKRequestNotAllowedException";
NSString *const RKAffectedRequestUserInfoKey = @"RKAffectedRequestUserInfoKey";

@implementation RKURLRequestStub

static NSString *gHTTPVersionString = @"HTTP/1.1";
+ (void)setHTTPVersionString:(NSString *)versionString
{
    gHTTPVersionString = [versionString copy];
}

+ (NSString *)HTTPVersionString
{
    return [gHTTPVersionString copy];
}

#pragma mark - Configuring the Response

- (void)andReturnData:(NSData *)data withHeaders:(NSDictionary *)headers andStatusCode:(NSInteger)statusCode
{
    NSParameterAssert(data);
    
    NSMutableDictionary *extendedHeaders = [headers mutableCopy];
    extendedHeaders[@"Status"] = [NSString stringWithFormat:@"%ld", (long)statusCode];
    
    self.response = [[NSHTTPURLResponse alloc] initWithURL:self.URL
                                                statusCode:statusCode
                                               HTTPVersion:[self.class HTTPVersionString]
                                              headerFields:extendedHeaders];
    self.responseBody = data;
}

#pragma mark -

- (void)andReturnString:(NSString *)string withHeaders:(NSDictionary *)headers andStatusCode:(NSInteger)statusCode
{
    NSParameterAssert(string);
    
    NSData *stringData = [string dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableDictionary *extendedHeaders = [NSMutableDictionary dictionary];
    extendedHeaders[@"Content-Type"] = @"application/json";
    extendedHeaders[@"Content-Size"] = [NSString stringWithFormat:@"%lu", (unsigned long)stringData.length];
    [extendedHeaders addEntriesFromDictionary:headers];
    [self andReturnData:stringData withHeaders:extendedHeaders andStatusCode:statusCode];
}

- (void)andReturnJSON:(id)jsonObject withHeaders:(NSDictionary *)headers andStatusCode:(NSInteger)statusCode
{
    NSParameterAssert(jsonObject);
    
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonObject options:kNilOptions error:&error];
    if(!jsonData) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Could not create JSON data from object."
                                     userInfo:@{NSUnderlyingErrorKey: error, NSAffectedObjectsErrorKey: @[jsonObject]}];
    }
    
    NSMutableDictionary *extendedHeaders = [NSMutableDictionary dictionary];
    extendedHeaders[@"Content-Type"] = @"application/json";
    extendedHeaders[@"Content-Size"] = [NSString stringWithFormat:@"%lu", (unsigned long)jsonData.length];
    [extendedHeaders addEntriesFromDictionary:headers];
    [self andReturnData:jsonData withHeaders:extendedHeaders andStatusCode:statusCode];
}

- (void)andReturnPlist:(id)plistObject withHeaders:(NSDictionary *)headers andStatusCode:(NSInteger)statusCode
{
    NSParameterAssert(plistObject);
    
    NSError *error = nil;
    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:plistObject format:NSPropertyListXMLFormat_v1_0 options:kNilOptions error:&error];
    if(!plistData) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Could not create property list data from object."
                                     userInfo:@{NSUnderlyingErrorKey: error, NSAffectedObjectsErrorKey: @[plistObject]}];
    }
    
    NSMutableDictionary *extendedHeaders = [NSMutableDictionary dictionary];
    extendedHeaders[@"Content-Type"] = @"application/xml";
    extendedHeaders[@"Content-Size"] = [NSString stringWithFormat:@"%lu", (unsigned long)plistData.length];
    [extendedHeaders addEntriesFromDictionary:headers];
    [self andReturnData:plistData withHeaders:extendedHeaders andStatusCode:statusCode];
}

@end

#pragma mark -

@interface RKTestURLProtocol ()

@property BOOL canceled;

@end

#pragma mark -

@implementation RKTestURLProtocol

static NSMutableArray *gRegisteredStubs = nil;

#pragma mark - Routes

+ (void)load
{
    [NSURLProtocol registerClass:[self class]];
}

+ (void)initialize
{
    if(!gRegisteredStubs) {
        gRegisteredStubs = [NSMutableArray array];
    }
    
    [super initialize];
}

#pragma mark - Lifecycle

static int32_t gActiveCount = 0;

+ (void)setup
{
    OSAtomicIncrement32Barrier(&gActiveCount);
}

+ (void)teardown
{
    OSMemoryBarrier();
    if(gActiveCount > 0) {
        OSAtomicDecrement32Barrier(&gActiveCount);
        
        @synchronized(gRegisteredStubs) {
            [gRegisteredStubs removeAllObjects];
        }
    }
}

+ (BOOL)isActive
{
    OSMemoryBarrier();
    return (gActiveCount > 0);
}

#pragma mark - Stubbing Requests

+ (void)addStub:(RKURLRequestStub *)request
{
    NSParameterAssert(request);
    
    @synchronized(gRegisteredStubs) {
        [gRegisteredStubs addObject:request];
    }
}

+ (void)removeStub:(RKURLRequestStub *)request
{
    NSParameterAssert(request);
    
    @synchronized(gRegisteredStubs) {
        [gRegisteredStubs removeObject:request];
    }
}

+ (NSArray *)stubs
{
    @synchronized(gRegisteredStubs) {
        return [gRegisteredStubs copy];
    }
}

#pragma mark -

+ (RKURLRequestStub *)stubRequestToURL:(NSURL *)url withMethod:(NSString *)method headers:(NSDictionary *)headers andBody:(NSData *)body
{
    NSParameterAssert(url);
    NSParameterAssert(method);
    
    if(![self isActive]) {
        [NSException raise:NSInternalInconsistencyException format:@"Cannot stub requests without activating RKTestURLProtocol first."];
    }
    
    RKURLRequestStub *stub = [RKURLRequestStub new];
    
    stub.URL = url;
    stub.HTTPMethod = method;
    stub.HTTPHeaders = headers;
    stub.HTTPBody = body;
    
    [self addStub:stub];
    
    return stub;
}

+ (RKURLRequestStub *)stubGetRequestToURL:(NSURL *)url withHeaders:(NSDictionary *)headers
{
    return [self stubRequestToURL:url withMethod:@"GET" headers:headers andBody:nil];
}

+ (RKURLRequestStub *)stubDeleteRequestToURL:(NSURL *)url withHeaders:(NSDictionary *)headers
{
    return [self stubRequestToURL:url withMethod:@"DELETE" headers:headers andBody:nil];
}

+ (RKURLRequestStub *)stubPostRequestToURL:(NSURL *)url withHeaders:(NSDictionary *)headers andBody:(NSData *)body
{
    NSParameterAssert(body);
    return [self stubRequestToURL:url withMethod:@"POST" headers:headers andBody:body];
}

+ (RKURLRequestStub *)stubPutRequestToURL:(NSURL *)url withHeaders:(NSDictionary *)headers andBody:(NSData *)body
{
    NSParameterAssert(body);
    return [self stubRequestToURL:url withMethod:@"POST" headers:headers andBody:body];
}

#pragma mark - Internal

+ (RKURLRequestStub *)stubForRequest:(NSURLRequest *)request
{
    return RKCollectionFindFirstMatch(self.stubs, ^BOOL(RKURLRequestStub *stub) {
        BOOL URLsAreEqual = [stub.URL isEqual:request.URL];
        BOOL headersAreEqual = ((stub.HTTPHeaders == request.allHTTPHeaderFields) ||
                                [stub.HTTPHeaders isEqual:request.allHTTPHeaderFields]);
        BOOL methodsAreEqual = ((stub.HTTPMethod == request.HTTPMethod) ||
                                [stub.HTTPMethod isEqual:request.HTTPMethod]);
        BOOL bodiesAreEqual = ((stub.HTTPBody == request.HTTPBody) ||
                               [stub.HTTPBody isEqual:request.HTTPBody]);
        return (URLsAreEqual && headersAreEqual && methodsAreEqual && bodiesAreEqual);
    });
}

#pragma mark - Primitive Methods

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if(![self isActive])
        return NO;
    
    if([self stubForRequest:request] == nil) {
        @throw [NSException exceptionWithName:RKRequestNotAllowedException
                                       reason:[NSString stringWithFormat:@"Real outgoing connections are not allowed. Unregistered %@ request to %@ with headers %@", request.HTTPMethod, request.URL, request.allHTTPHeaderFields]
                                     userInfo:@{RKAffectedRequestUserInfoKey: request ?: [NSNull null]}];
        return NO;
    } else {
        return YES;
    }
}

- (void)startLoading
{
    RKURLRequestStub *requestStub = [[self class] stubForRequest:self.request];
    [[RKQueueManager commonQueue] addOperationWithBlock:^{
        NSHTTPURLResponse *response = requestStub.response;
        if(self.canceled)
            return;
        
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        
        if(self.canceled)
            return;
        
        [self.client URLProtocol:self didLoadData:requestStub.responseBody];
        
        if(self.canceled)
            return;
        
        [self.client URLProtocolDidFinishLoading:self];
    }];
}

- (void)stopLoading
{
    self.canceled = YES;
}

@end
