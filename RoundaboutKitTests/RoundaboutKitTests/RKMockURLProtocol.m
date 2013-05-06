//
//  RKMockURLProtocol.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import "RKMockURLProtocol.h"

@implementation RKMockURLProtocolRoute

- (BOOL)isEqual:(id)object
{
    RKMockURLProtocolRoute *other = RK_TRY_CAST(RKMockURLProtocolRoute, object);
    if(other) {
        return ([other.URL isEqual:self.URL] &&
                [other.method isEqualToString:self.method] &&
                [other.headers isEqual:self.headers] &&
                [other.responseData isEqual:self.responseData]);
    }
    
    return NO;
}

- (NSUInteger)hash
{
    return 42 + ([self.URL hash] + [self.method hash]) >> 1;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@:%p URL => %@, method => %@>", NSStringFromClass([self class]), self, self.URL, self.method];
}

@end

#pragma mark -

static NSMutableArray *_Routes = nil;

@implementation RKMockURLProtocol

#pragma mark - Routes

+ (void)initialize
{
    if(!_Routes) {
        _Routes = [NSMutableArray array];
        
        [NSURLProtocol registerClass:[self class]];
    }
    
    [super initialize];
}

#pragma mark -

+ (void)on:(NSURL *)url withMethod:(NSString *)method yieldStatusCode:(NSInteger)statusCode headers:(NSDictionary *)headers data:(NSData *)data
{
    NSParameterAssert(url);
    NSParameterAssert(method);
    NSParameterAssert(headers);
    NSParameterAssert(data);
    
    RKMockURLProtocolRoute *route = [RKMockURLProtocolRoute new];
    
    route.URL = url;
    route.method = method;
    route.statusCode = statusCode;
    route.headers = headers;
    route.responseData = data;
    
    @synchronized(_Routes) {
        [_Routes addObject:route];
    }
}

+ (void)on:(NSURL *)url withMethod:(NSString *)method yieldError:(NSError *)error
{
    NSParameterAssert(url);
    NSParameterAssert(method);
    NSParameterAssert(error);
    
    RKMockURLProtocolRoute *route = [RKMockURLProtocolRoute new];
    
    route.URL = url;
    route.method = method;
    route.error = error;
    
    @synchronized(_Routes) {
        [_Routes addObject:route];
    }
}

#pragma mark -

+ (void)removeAllRoutes
{
    @synchronized(_Routes) {
        [_Routes removeAllObjects];
    }
}

+ (NSArray *)routes
{
    @synchronized(_Routes) {
        return [_Routes copy];
    }
}

+ (RKMockURLProtocolRoute *)routeForRequest:(NSURLRequest *)request
{
    return RKCollectionFindFirstMatch([[self class] routes], ^BOOL(RKMockURLProtocolRoute *route) {
        return ([route.URL isEqual:request.URL] &&
                [route.method isEqualToString:request.HTTPMethod]);
    });
}

#pragma mark - Primitive Methods

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return ([self routeForRequest:request] != nil);
}

- (void)startLoading
{
    RKMockURLProtocolRoute *route = [[self class] routeForRequest:self.request];
    if(route.error) {
        [self.client URLProtocol:self didFailWithError:route.error];
    } else {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:route.URL
                                                                  statusCode:route.statusCode
                                                                 HTTPVersion:@"HTTP/1.1"
                                                                headerFields:route.headers];
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:route.responseData];
        [self.client URLProtocolDidFinishLoading:self];
    }
}

- (void)stopLoading
{
}

@end
