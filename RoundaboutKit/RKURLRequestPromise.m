//
//  RKURLRequestPromise.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/31/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#import "RKURLRequestPromise.h"
#import "RKConnectivityManager.h"
#import "RKActivityManager.h"
#import "RKPossibility.h"

#if TARGET_OS_IPHONE
#   import <UIKit/UIKit.h>
#else
#   import <Cocoa/Cocoa.h>
#endif /* TARGET_OS_IPHONE */

NSString *const RKURLRequestPromiseErrorDomain = @"RKURLRequestPromiseErrorDomain";
NSString *const RKURLRequestPromiseCacheIdentifierErrorUserInfoKey = @"RKURLRequestPromiseCacheIdentifierErrorUserInfoKey";

static NSString *const kETagHeaderKey = @"Etag";
static NSString *const kExpiresHeaderKey = @"Expires";
static NSString *const kDefaultRevision = @"-1";

@interface RKURLRequestPromise () <NSURLConnectionDelegate>

#pragma mark - Internal Properties

///The underlying connection.
@property NSURLConnection *connection;

///Whether or not the cache has been successfully loaded.
@property BOOL isCacheLoaded;

#pragma mark - Readwrite Properties

///Readwrite
@property (readwrite, RK_NONATOMIC_IOSONLY) NSURLRequest *request;

///Readwrite.
@property (copy, readwrite) NSHTTPURLResponse *response;

///Readwrite
@property (readwrite, RK_NONATOMIC_IOSONLY) id <RKURLRequestPromiseCacheManager> cacheManager;

///Readwrite
@property (readwrite, RK_NONATOMIC_IOSONLY) BOOL useCacheWhenOffline;

@end

#pragma mark -

@implementation RKURLRequestPromise {
    BOOL _isInOfflineMode;
    NSMutableData *_loadedData;
    
    RKSimplePostProcessorBlock _legacyPostProcessor;
}

#pragma mark - Lifecycle

- (void)dealloc
{
    [self cancel:nil];
}

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithRequest:(NSURLRequest *)request
         cacheManager:(id <RKURLRequestPromiseCacheManager>)cacheManager
  useCacheWhenOffline:(BOOL)useCacheWhenOffline
         requestQueue:(NSOperationQueue *)requestQueue
{
    NSParameterAssert(request);
    NSParameterAssert(requestQueue);
    
    if((self = [super init])) {
        self.request = request;
        self.cacheManager = cacheManager;
        self.useCacheWhenOffline = useCacheWhenOffline;
        self.requestQueue = requestQueue;
        
        self.cacheIdentifier = [request.URL absoluteString];
        
        self.connectivityManager = [RKConnectivityManager defaultInternetConnectivityManager];
    }
    
    return self;
}

- (id)initWithRequest:(NSURLRequest *)request
         cacheManager:(id <RKURLRequestPromiseCacheManager>)cacheManager
         requestQueue:(NSOperationQueue *)requestQueue
{
    return [self initWithRequest:request cacheManager:cacheManager useCacheWhenOffline:YES requestQueue:requestQueue];
}

- (id)initWithRequest:(NSURLRequest *)request requestQueue:(NSOperationQueue *)requestQueue
{
    return [self initWithRequest:request cacheManager:nil useCacheWhenOffline:NO requestQueue:requestQueue];
}

#pragma mark - Identity

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@:%p %@ to %@>", NSStringFromClass([self class]), self, self.request.HTTPMethod, self.request.URL];
}

#pragma mark - Realization

- (void)fire
{
    NSAssert((self.connection == nil),
             @"Cannot realize a %@ more than once.", NSStringFromClass([self class]));
    
    [_requestQueue addOperationWithBlock:^{
        @synchronized(self) {
            _loadedData = [NSMutableData new];
        }
        
        _isInOfflineMode = !self.connectivityManager.isConnected;
        [[RKActivityManager sharedActivityManager] incrementActivityCount];
        
        if(_preflight) {
            NSError *preflightError = nil;
            NSURLRequest *newRequest = nil;
            if((newRequest = _preflight(self.request, &preflightError))) {
                self.request = newRequest;
            } else {
                [self invokeFailureCallbackWithError:preflightError];
                return;
            }
        }
        
        if(_isInOfflineMode) {
            [self.requestQueue addOperationWithBlock:^{
                [self loadCacheAndReportError:YES];
            }];
        } else {
#if RKURLRequestPromise_Option_MeasureResponseTimes
            self.startDate = [NSDate date];
#endif /* #if RKURLRequestPromise_Option_MeasureResponseTimes */
            
            self.connection = [[NSURLConnection alloc] initWithRequest:self.request
                                                              delegate:self
                                                      startImmediately:NO];
            
            [self.connection setDelegateQueue:self.requestQueue];
            [self.connection start];
        }
        
#if RKURLRequestPromise_Option_LogRequests
        RKLogInfo(@"Outgoing request to <%@>, POST data <%@>", self.request.URL, (self.request.HTTPBody? [[NSString alloc] initWithData:self.request.HTTPBody encoding:NSUTF8StringEncoding] : @"(none)"));
#endif /* RKURLRequestPromise_Option_LogRequests */
    }];
}

- (void)cancel:(id)sender
{
    if(!self.cancelled && _connection) {
        [self.connection cancel];
        @synchronized(self) {
             _loadedData = nil;
        }
        
#if RKURLRequestPromise_Option_LogRequests
        RKLogInfo(@"Outgoing request to <%@> cancelled", self.request.URL);
#endif /* RKURLRequestPromise_Option_LogRequests */
        
        [[RKActivityManager sharedActivityManager] decrementActivityCount];
        
        self.cancelled = YES;
    }
}

#pragma mark - Cache Support

- (BOOL)loadCacheAndReportError:(BOOL)reportError
{
    if(!self.cacheManager || self.cacheIdentifier == nil)
        return NO;
    
    if(self.cancelled) {
        if(!_isInOfflineMode)
            [[RKActivityManager sharedActivityManager] decrementActivityCount];
        
        return YES;
    }
    
    NSError *error = nil;
    NSData *data = [self.cacheManager cachedDataForIdentifier:self.cacheIdentifier error:&error];
    if(data) {
        self.isCacheLoaded = YES;
        
        [self invokeSuccessCallbackWithData:data];
    } else {
        NSError *removeError = nil;
        BOOL removedCache = [self.cacheManager removeCacheForIdentifier:self.cacheIdentifier error:&removeError];
        
        if(reportError) {
            NSDictionary *userInfo = nil;
            if(removedCache) {
                userInfo = @{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not load cached data for identifier %@.", self.cacheIdentifier],
                    RKURLRequestPromiseCacheIdentifierErrorUserInfoKey: self.cacheIdentifier,
                };
            } else {
                userInfo = @{
                    NSUnderlyingErrorKey: error,
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not load cached data for identifier %@.", self.cacheIdentifier],
                    RKURLRequestPromiseCacheIdentifierErrorUserInfoKey: self.cacheIdentifier,
                    @"RKURLRequestPromiseCacheRemovalErrorUserInfoKey": removeError,
                };
            }
            NSError *highLevelError = [NSError errorWithDomain:RKURLRequestPromiseErrorDomain
                                                          code:kRKURLRequestPromiseErrorCannotLoadCache
                                                      userInfo:userInfo];
            [self invokeFailureCallbackWithError:highLevelError];
            
            return NO;
        }
    }
    
    return YES;
}

- (RKPromise *)cachedData
{
    if(!self.cacheManager || self.cacheIdentifier == nil)
        return nil;
    
    RKPromise *cachedDataPromise = [RKPromise new];
    [cachedDataPromise addPostProcessors:RKCollectionDeepCopy(self.postProcessors)];
    
    [self.requestQueue addOperationWithBlock:^{
        NSError *error = nil;
        NSData *data = [self.cacheManager cachedDataForIdentifier:self.cacheIdentifier error:&error];
        if(data) {
            [cachedDataPromise accept:data];
        } else if(error) {
            NSDictionary *userInfo = @{
                NSUnderlyingErrorKey: error,
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not load cached data for identifier %@.", self.cacheIdentifier],
                RKURLRequestPromiseCacheIdentifierErrorUserInfoKey: self.cacheIdentifier,
            };
            NSError *highLevelError = [NSError errorWithDomain:RKURLRequestPromiseErrorDomain
                                                          code:kRKURLRequestPromiseErrorCannotLoadCache
                                                      userInfo:userInfo];
            [cachedDataPromise reject:highLevelError];
        }
    }];
    
    return cachedDataPromise;
}

#pragma mark - Invoking Callbacks

- (void)invokeSuccessCallbackWithData:(NSData *)data
{
    if(self.cancelled)
        return;
    
    [[RKActivityManager sharedActivityManager] decrementActivityCount];
    
#if RKURLRequestPromise_Option_LogResponses
    RKLogInfo(@"%@Response for request to <%@>: %@", (_isInOfflineMode? @"(offline) " : @""), self.request.URL, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
#endif /* RKURLRequestPromise_Option_LogResponses */
    
    //Post-processors can be long running.
    if(self.cancelled)
        return;
    
    [self accept:data];
}

- (void)invokeFailureCallbackWithError:(NSError *)error
{
    if(self.cancelled)
        return;
    
    [[RKActivityManager sharedActivityManager] decrementActivityCount];
    
#if RKURLRequestPromise_Option_LogErrors
    RKLogInfo(@"Error for request to <%@>: %@", self.request.URL, error);
#endif /* RKURLRequestPromise_Option_LogErrors */
    
    [self reject:error];
}

#pragma mark - <NSURLConnectionDelegate>

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    switch (error.code) {
        case NSURLErrorCannotFindHost:
        case NSURLErrorCannotConnectToHost:
        case NSURLErrorNetworkConnectionLost:
        case NSURLErrorDNSLookupFailed:
        case NSURLErrorNotConnectedToInternet:
        case NSURLErrorRedirectToNonExistentLocation:
        case NSURLErrorBadServerResponse: {
            if(self.isCacheLoaded) {
                //Return early, for we have loaded our cache.
                return;
            }
            
            break;
        }
            
        default: {
            break;
        }
    }
    
    [self invokeFailureCallbackWithError:error];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response
{
    self.response = response;
    
    if(!self.cacheManager || self.cancelled || self.cacheIdentifier == nil)
        return;
    
    NSString *cacheMarker = response.allHeaderFields[kETagHeaderKey] ?: response.allHeaderFields[kExpiresHeaderKey];
    NSString *storedCacheMarker = [self.cacheManager revisionForIdentifier:self.cacheIdentifier];
    if(cacheMarker && storedCacheMarker && [cacheMarker caseInsensitiveCompare:storedCacheMarker] == NSOrderedSame) {
        [self.connection cancel];
        @synchronized(self) {
            _loadedData = nil;
        }
        
        if(self.cancelWhenRemoteDataUnchanged) {
            [[RKActivityManager sharedActivityManager] decrementActivityCount];
        } else {
            [self loadCacheAndReportError:YES];
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    @synchronized(self) {
        [_loadedData appendData:data];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if(self.cancelled)
        return;
    
    __block NSData *loadedData = nil;
    @synchronized(self) {
        loadedData = _loadedData;
    }
    
#if RKURLRequestPromise_Option_MeasureResponseTimes
    _CumulativeResponseTime += -[self.startDate timeIntervalSinceNow];
    _NumberOfCompletedRequests++;
#endif /* #if RKURLRequestPromise_Option_MeasureResponseTimes */
    
    if(self.cacheManager) {
        NSString *cacheMarker = self.response.allHeaderFields[kETagHeaderKey] ?: self.response.allHeaderFields[kExpiresHeaderKey];
        if(!cacheMarker && self.useCacheWhenOffline)
            cacheMarker = kDefaultRevision;
        
        if(cacheMarker) {
            NSError *error = nil;
            if(![self.cacheManager cacheData:loadedData
                               forIdentifier:self.cacheIdentifier
                                withRevision:cacheMarker
                                       error:&error]) {
                NSDictionary *userInfo = @{
                    NSUnderlyingErrorKey: error,
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not write data to cache for identifier %@.", self.cacheIdentifier],
                    RKURLRequestPromiseCacheIdentifierErrorUserInfoKey: self.cacheIdentifier,
                };
                NSError *highLevelError = [NSError errorWithDomain:RKURLRequestPromiseErrorDomain
                                                              code:kRKURLRequestPromiseErrorCannotWriteCache
                                                          userInfo:userInfo];
                [self invokeFailureCallbackWithError:highLevelError];
            }
        }
    }
    
    [self invokeSuccessCallbackWithData:loadedData];
    
    _connection = nil;
    @synchronized(self) {
        _loadedData = nil;
    }
}

#pragma mark -

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
    return [self.authenticationHandler request:self canHandlerAuthenticateProtectionSpace:protectionSpace];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    [self.authenticationHandler request:self handleAuthenticationChallenge:challenge];
}

@end

#pragma mark - Deprecated

RK_OVERLOADABLE RKSimplePostProcessorBlock RKPostProcessorBlockChain(RKSimplePostProcessorBlock source,
                                                                     RKSimplePostProcessorBlock refiner)
{
    NSCParameterAssert(source);
    NSCParameterAssert(refiner);
    
    return ^RKPossibility *(RKPossibility *maybeData, RKURLRequestPromise *request) {
        RKPossibility *refinedMaybeData = source(maybeData, request);
        return refiner(refinedMaybeData, request);
    };
}

#pragma mark -

@implementation RKURLRequestPromise (RKDeprecated)

- (void)setPostProcessor:(RKSimplePostProcessorBlock)postProcessor
{
    _legacyPostProcessor = postProcessor;
    
    [self removeAllPostProcessors];
    [super addPostProcessors:@[ [[RKSimplePostProcessor alloc] initWithBlock:postProcessor] ]];
}

- (RKSimplePostProcessorBlock)postProcessor
{
    return _legacyPostProcessor;
}

- (void)addPostProcessors:(NSArray *)processors
{
    if(_legacyPostProcessor != nil)
        [NSException raise:NSInternalInconsistencyException
                    format:@"Cannot use %s when an old-style post processor is set.", __PRETTY_FUNCTION__];
    
    [super addPostProcessors:processors];
}

@end
