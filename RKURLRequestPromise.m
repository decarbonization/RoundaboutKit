//
//  RKURLRequestPromise.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/31/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#import "RKURLRequestPromise.h"
#import "RKReachability.h"
#import "RKActivityManager.h"

NSString *const RKURLRequestPromiseErrorDomain = @"RKURLRequestPromiseErrorDomain";
NSString *const RKURLRequestPromiseCacheIdentifierErrorUserInfoKey = @"RKURLRequestPromiseCacheIdentifierErrorUserInfoKey";

static NSString *const kETagHeaderKey = @"Etag";
static NSString *const kDefaultETagKey = @"-1";

#pragma mark - RKPostProcessorBlock

RK_OVERLOADABLE RKPostProcessorBlock RKPostProcessorBlockChain(RKPostProcessorBlock source,
                                                               RKPostProcessorBlock refiner)
{
    NSCParameterAssert(source);
    NSCParameterAssert(refiner);
    
    return ^RKPossibility *(RKPossibility *maybeData) {
        RKPossibility *refinedMaybeData = source(maybeData);
        return refiner(refinedMaybeData);
    };
}

RKPostProcessorBlock const kRKJSONPostProcessorBlock = ^RKPossibility *(RKPossibility *maybeData) {
    return RKRefinePossibility(maybeData, ^RKPossibility *(NSData *data) {
        NSError *error = nil;
        id result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if(result) {
            return [[RKPossibility alloc] initWithValue:result];
        } else {
            return [[RKPossibility alloc] initWithError:error];
        }
    }, nil /* ignore empty */, nil /* ignore error */);
};

#pragma mark -

@interface RKURLRequestPromise () <NSURLConnectionDelegate>

#pragma mark - Internal Properties

///The on success callback block.
@property (copy, RK_NONATOMIC_IOSONLY) RKPromiseSuccessBlock onSuccess;

///The on failure callback block.
@property (copy, RK_NONATOMIC_IOSONLY) RKPromiseFailureBlock onFailure;

///The queue to invoke the callback blocks on.
@property (RK_NONATOMIC_IOSONLY) NSOperationQueue *callbackQueue;

#pragma mark -

@property (copy, RK_NONATOMIC_IOSONLY) NSDictionary *responseHeaderFields;

///The underlying connection.
@property NSURLConnection *connection;

///Whether or not the cache has been successfully loaded.
@property BOOL isCacheLoaded;

#pragma mark - Readwrite Properties

///Readwrite
@property (readwrite, RK_NONATOMIC_IOSONLY) NSURLRequest *request;

///Readwrite
@property (readwrite, RK_NONATOMIC_IOSONLY) id <RKURLRequestPromiseCacheManager> cacheManager;

///Readwrite
@property (readwrite, RK_NONATOMIC_IOSONLY) BOOL useCacheWhenOffline;

@end

#pragma mark -

@implementation RKURLRequestPromise {
    BOOL _isInOfflineMode;
    NSMutableData *_loadedData;
}

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
    }
    
    return self;
}

#pragma mark - Realization

- (void)executeWithSuccessBlock:(RKPromiseSuccessBlock)onSuccess
                   failureBlock:(RKPromiseFailureBlock)onFailure
                  callbackQueue:(NSOperationQueue *)callbackQueue
{
    NSParameterAssert(onSuccess);
    NSParameterAssert(onFailure);
    NSParameterAssert(callbackQueue);
    
    NSAssert((self.connection == nil),
             @"Cannot realize a %@ more than once.", NSStringFromClass([self class]));
    
    [_requestQueue addOperationWithBlock:^{
        self.onSuccess = onSuccess;
        self.onFailure = onFailure;
        self.callbackQueue = callbackQueue;
        
        @synchronized(self) {
            _loadedData = [NSMutableData new];
        }
        
        _isInOfflineMode = ![RKReachability defaultInternetConnectionReachability].isConnected;
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
            [self loadCache];
        } else {
            self.connection = [[NSURLConnection alloc] initWithRequest:self.request
                                                              delegate:self
                                                      startImmediately:NO];
            
            [self.connection setDelegateQueue:self.requestQueue];
            [self.connection start];
        }
        
#if RKURLRequestPromise_Option_LogRequests
        NSLog(@"[DEBUG] Outgoing request to <%@>, POST data <%@>", self.request.URL, (self.request.HTTPBody? [[NSString alloc] initWithData:self.request.HTTPBody encoding:NSUTF8StringEncoding] : @"(none)"));
#endif /* RKURLRequestPromise_Option_LogRequests */
    }];
}

- (void)cancel:(id)sender
{
    if(!self.cancelled) {
        [self.connection cancel];
        @synchronized(self) {
             _loadedData = nil;
        }
        
#if RKURLRequestPromise_Option_LogRequests
        NSLog(@"[DEBUG] Outgoing request to <%@> cancelled", self.request.URL);
#endif /* RKURLRequestPromise_Option_LogRequests */
        
        [[RKActivityManager sharedActivityManager] decrementActivityCount];
        
        self.cancelled = YES;
    }
}

#pragma mark - Cache Support

- (void)loadCache
{
    if(!self.cacheManager || self.cacheIdentifier == nil)
        return;
    
    if(self.cancelled) {
        if(!_isInOfflineMode)
            [[RKActivityManager sharedActivityManager] decrementActivityCount];
        
        return;
    }
    
    [self.requestQueue addOperationWithBlock:^{
        NSError *error = nil;
        NSData *data = [self.cacheManager cachedDataForIdentifier:self.cacheIdentifier error:&error];
        if(data) {
            self.isCacheLoaded = YES;
            
            [self invokeSuccessCallbackWithData:data];
        } else if(_isInOfflineMode) {
            NSDictionary *userInfo = @{
                NSUnderlyingErrorKey: error,
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not load cached data for identifier %@.", self.cacheIdentifier],
                RKURLRequestPromiseCacheIdentifierErrorUserInfoKey: self.cacheIdentifier,
            };
            NSError *highLevelError = [NSError errorWithDomain:RKURLRequestPromiseErrorDomain
                                                          code:kRKURLRequestPromiseErrorCannotLoadCache
                                                      userInfo:userInfo];
            [self invokeFailureCallbackWithError:highLevelError];
        }
    }];
}

- (void)loadCachedDataWithCallbackQueue:(NSOperationQueue *)callbackQueue block:(RKURLRequestPromiseCacheLoadingBlock)block
{
    NSParameterAssert(callbackQueue);
    NSParameterAssert(block);
    
    if(!self.cacheManager || self.cacheIdentifier == nil)
        return;
    
    [self.requestQueue addOperationWithBlock:^{
        NSError *error = nil;
        NSData *data = [self.cacheManager cachedDataForIdentifier:self.cacheIdentifier error:&error];
        if(data) {
            RKPossibility *maybeValue = self.postProcessor([[RKPossibility alloc] initWithValue:data]);
            [callbackQueue addOperationWithBlock:^{
                block(maybeValue);
            }];
        } else if(error) {
            NSDictionary *userInfo = @{
                NSUnderlyingErrorKey: error,
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not load cached data for identifier %@.", self.cacheIdentifier],
                RKURLRequestPromiseCacheIdentifierErrorUserInfoKey: self.cacheIdentifier,
            };
            NSError *highLevelError = [NSError errorWithDomain:RKURLRequestPromiseErrorDomain
                                                          code:kRKURLRequestPromiseErrorCannotLoadCache
                                                      userInfo:userInfo];
            [callbackQueue addOperationWithBlock:^{
                block([[RKPossibility alloc] initWithError:highLevelError]);
            }];
        } else {
            [callbackQueue addOperationWithBlock:^{
                block([[RKPossibility alloc] initEmpty]);
            }];
        }
    }];
}

#pragma mark - Invoking Callbacks

- (void)invokeSuccessCallbackWithData:(NSData *)data
{
    if(self.cancelled)
        return;
    
    [[RKActivityManager sharedActivityManager] decrementActivityCount];
    
#if RKURLRequestPromise_Option_LogResponses
    NSLog(@"[DEBUG] %@Response for request to <%@>: %@", (_isInOfflineMode? @"(offline) " : @""), self.request.URL, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
#endif /* RKURLRequestPromise_Option_LogResponses */
    
    RKPossibility *maybeValue = nil;
    if(_postProcessor) {
        maybeValue = _postProcessor([[RKPossibility alloc] initWithValue:data]);
    }
    
    [self.callbackQueue addOperationWithBlock:^{
        self.isFinished = YES;
        
        if(maybeValue) {
            if(maybeValue.state == kRKPossibilityStateError) {
                self.onFailure(maybeValue.error);
            } else {
                self.onSuccess(maybeValue.value);
            }
        } else {
            self.onSuccess(data);
        }
    }];
}

- (void)invokeFailureCallbackWithError:(NSError *)error
{
    if(self.cancelled)
        return;
    
    [[RKActivityManager sharedActivityManager] decrementActivityCount];
    
#if RKURLRequestPromise_Option_LogErrors
    NSLog(@"[DEBUG] Error for request to <%@>: %@", self.request.URL, error);
#endif /* RKURLRequestPromise_Option_LogErrors */
    
    [self.callbackQueue addOperationWithBlock:^{
        self.onFailure(error);
    }];
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
                [self.callbackQueue addOperationWithBlock:^{
                    if(!self.isFinished)
                        self.isFinished = YES;
                }];
                
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
    if(!self.cacheManager || self.cancelled || self.cacheIdentifier == nil)
        return;
    
    self.responseHeaderFields = response.allHeaderFields;
    
    NSString *etag = self.responseHeaderFields[kETagHeaderKey];
    NSString *cachedEtag = [self.cacheManager revisionForIdentifier:self.cacheIdentifier];
    if(etag && cachedEtag && [etag caseInsensitiveCompare:cachedEtag] == NSOrderedSame) {
        [self.connection cancel];
        @synchronized(self) {
            _loadedData = nil;
        }
        
        if(self.cancelWhenRemoteDataUnchanged) {
            [[RKActivityManager sharedActivityManager] decrementActivityCount];
            
            [self.callbackQueue addOperationWithBlock:^{
                if(!self.isFinished)
                    self.isFinished = YES;
            }];
        } else {
            [self loadCache];
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
    
    if(self.cacheManager) {
        NSString *etag = self.responseHeaderFields[kETagHeaderKey];
        if(!etag && self.useCacheWhenOffline)
            etag = kDefaultETagKey;
        
        if(etag) {
            NSError *error = nil;
            if(![self.cacheManager cacheData:loadedData
                               forIdentifier:self.cacheIdentifier
                                withRevision:etag
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
