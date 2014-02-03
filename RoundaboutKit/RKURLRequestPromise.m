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

@property (readwrite, RK_NONATOMIC_IOSONLY) NSURLRequest *request;
@property (copy, readwrite) NSHTTPURLResponse *response;
@property (readwrite, RK_NONATOMIC_IOSONLY) id <RKURLRequestPromiseCacheManager> cacheManager;
@property (readwrite, RK_NONATOMIC_IOSONLY) RKURLRequestPromiseOfflineBehavior offlineBehavior;

@end

#pragma mark -

@implementation RKURLRequestPromise {
    ///Whether or not the request started when its
    ///connection manager reported being offline.
    BOOL _isInOfflineMode;
    
    
    ///Buffer that temporarily stores all data loaded by the request. See `_loadedDataLock`.
    NSMutableData *_loadedData;
    
    ///The lock used to synchronize access to the `_loadedData` ivar
    ///between threads. It is possible for the request queue that the
    ///promise executes on to allow for an arbitrary number of concurrent
    ///operations, as such we have to synchronize access to the loaded
    ///data buffer to prevent race conditions and crashes both when the
    ///ivar is set, and when the data is mutated.
    NSLock *_loadedDataLock;
    
    
    ///The legacy post processor block. Used by the RKDeprecated category.
    RKSimplePostProcessorBlock _legacyPostProcessor;
    
    NSOperationQueue *_legacyRequestQueue;
}

#pragma mark - Logging

///Whether or not activity logging is enabled.
static BOOL gActivityLoggingEnabled = NO;

+ (void)enableActivityLogging
{
    gActivityLoggingEnabled = YES;
}

+ (void)disableActivityLogging
{
    gActivityLoggingEnabled = NO;
}

#pragma mark - Work Queue

+ (NSOperationQueue *)sharedWorkQueue
{
    static NSOperationQueue *sharedWorkQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedWorkQueue = [NSOperationQueue new];
        sharedWorkQueue.name = @"com.roundabout.rk.RKURLRequestPromise.sharedWorkQueue";
        sharedWorkQueue.maxConcurrentOperationCount = 1;
    });
    
    return sharedWorkQueue;
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

- (instancetype)initWithRequest:(NSURLRequest *)request
                offlineBehavior:(RKURLRequestPromiseOfflineBehavior)offlineBehavior
                   cacheManager:(id <RKURLRequestPromiseCacheManager>)cacheManager
{
    NSParameterAssert(request);
    
    if((self = [super init])) {
        self.request = request;
        self.cacheIdentifier = [request.URL absoluteString];
        
        self.cacheManager = cacheManager;
        
        switch (offlineBehavior) {
            case kRKURLRequestPromiseOfflineBehaviorUseCacheIfAvailable:
                if(cacheManager)
                    self.offlineBehavior = kRKURLRequestPromiseOfflineBehaviorUseCacheIfAvailable;
                else
                    self.offlineBehavior = kRKURLRequestPromiseOfflineBehaviorFail;
                break;
                
            case kRKURLRequestPromiseOfflineBehaviorFail:
                self.offlineBehavior = kRKURLRequestPromiseOfflineBehaviorFail;
                break;
        }
        
        self.connectivityManager = [RKConnectivityManager defaultInternetConnectivityManager];
        
        _loadedDataLock = [NSLock new];
        _loadedDataLock.name = @"com.roundabout.rk.RKURLRequestPromise.loadedDataLock";
    }
    
    return self;
}

#pragma mark - Identity

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@:%p %@ to %@>", NSStringFromClass([self class]), self, self.request.HTTPMethod, self.request.URL];
}

#pragma mark - Properties

- (void)setConnectivityManager:(RKConnectivityManager *)connectivityManager
{
    if(!connectivityManager)
        [NSException raise:NSInvalidArgumentException format:@"Cannot assign a nil connectivity manager to RKURLRequestPromise instance."];
    
    _connectivityManager = connectivityManager;
}

#pragma mark - Realization

- (NSOperationQueue *)workQueue
{
    return _legacyRequestQueue ?: self.class.sharedWorkQueue;
}

- (void)fire
{
    NSOperationQueue *workQueue = self.workQueue;
    [workQueue addOperationWithBlock:^{
        [_loadedDataLock lock];
        _loadedData = [NSMutableData new];
        [_loadedDataLock unlock];
        
        _isInOfflineMode = !self.connectivityManager.isConnected;
        [[RKActivityManager sharedActivityManager] incrementActivityCount];
        
        if(_isInOfflineMode) {
            [workQueue addOperationWithBlock:^{
                [self loadCacheAndReportError:YES];
            }];
        } else {
            
            self.connection = [[NSURLConnection alloc] initWithRequest:self.request
                                                              delegate:self
                                                      startImmediately:NO];
            
            [self.connection setDelegateQueue:workQueue];
            [self.connection start];
        }
        
        if(gActivityLoggingEnabled)
            RKLogInfo(@"Outgoing request to <%@>, POST data <%@>", self.request.URL, (self.request.HTTPBody? [[NSString alloc] initWithData:self.request.HTTPBody encoding:NSUTF8StringEncoding] : @"(none)"));
    }];
}

#pragma mark - RKCancelable

@synthesize canceled = _canceled;

- (void)cancel:(id)sender
{
    if(!self.canceled && _connection) {
        [self.connection cancel];
        [_loadedDataLock lock];
        _loadedData = nil;
        [_loadedDataLock unlock];
        
        if(gActivityLoggingEnabled)
            RKLogInfo(@"Outgoing request to <%@> canceled", self.request.URL);
        
        [[RKActivityManager sharedActivityManager] decrementActivityCount];
        
        [self willChangeValueForKey:@"canceled"];
        _canceled = YES;
        [self didChangeValueForKey:@"canceled"];
    }
}

#pragma mark - Cache Support

- (BOOL)loadCacheAndReportError:(BOOL)reportError
{
    if(!self.cacheManager || self.cacheIdentifier == nil)
        return NO;
    
    if(self.canceled) {
        if(!_isInOfflineMode)
            [[RKActivityManager sharedActivityManager] decrementActivityCount];
        
        return YES;
    }
    
    NSError *error = nil;
    NSData *data = [self.cacheManager cachedDataForIdentifier:self.cacheIdentifier error:&error];
    if(data) {
        self.isCacheLoaded = YES;
        
        [self acceptWithData:data];
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
            [self rejectWithError:highLevelError];
            
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
    [cachedDataPromise addPostProcessors:self.postProcessors];
    
    [self.workQueue addOperationWithBlock:^{
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

- (void)acceptWithData:(NSData *)data
{
    if(self.canceled)
        return;
    
    [[RKActivityManager sharedActivityManager] decrementActivityCount];
    
    if(gActivityLoggingEnabled)
        RKLogInfo(@"%@Response for request to <%@>: %@", (_isInOfflineMode? @"(offline) " : @""), self.request.URL, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    
    [self accept:data];
}

- (void)rejectWithError:(NSError *)error
{
    if(self.canceled)
        return;
    
    [[RKActivityManager sharedActivityManager] decrementActivityCount];
    
    RKLogError(@"Error for request to <%@>: %@", self.request.URL, error);
    
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
    
    [self rejectWithError:error];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response
{
    self.response = response;
    
    if(!self.cacheManager || self.canceled || self.cacheIdentifier == nil)
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
    [_loadedDataLock lock];
    [_loadedData appendData:data];
    [_loadedDataLock unlock];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if(self.canceled)
        return;
    
    [_loadedDataLock lock];
    NSData *loadedData = _loadedData;
    _loadedData = nil;
    [_loadedDataLock unlock];
    
    if(self.cacheManager) {
        NSString *cacheMarker = self.response.allHeaderFields[kETagHeaderKey] ?: self.response.allHeaderFields[kExpiresHeaderKey];
        if(!cacheMarker && self.offlineBehavior == kRKURLRequestPromiseOfflineBehaviorUseCacheIfAvailable)
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
                [self rejectWithError:highLevelError];
            }
        }
    }
    
    [self acceptWithData:loadedData];
    
    _connection = nil;
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

- (instancetype)initWithRequest:(NSURLRequest *)request
                   cacheManager:(id <RKURLRequestPromiseCacheManager>)cacheManager
            useCacheWhenOffline:(BOOL)useCacheWhenOffline
                   requestQueue:(NSOperationQueue *)requestQueue
{
    NSParameterAssert(request);
    NSParameterAssert(requestQueue);
    
    RKURLRequestPromiseOfflineBehavior offlineBehavior;
    if(useCacheWhenOffline && cacheManager)
        offlineBehavior = kRKURLRequestPromiseOfflineBehaviorUseCacheIfAvailable;
    else
        offlineBehavior = kRKURLRequestPromiseOfflineBehaviorFail;
    
    if((self = [self initWithRequest:request
                     offlineBehavior:offlineBehavior
                        cacheManager:cacheManager])) {
        _legacyRequestQueue = requestQueue;
    }
    
    return self;
}

- (instancetype)initWithRequest:(NSURLRequest *)request
                   cacheManager:(id <RKURLRequestPromiseCacheManager>)cacheManager
                   requestQueue:(NSOperationQueue *)requestQueue
{
    return [self initWithRequest:request cacheManager:cacheManager useCacheWhenOffline:YES requestQueue:requestQueue];
}

- (instancetype)initWithRequest:(NSURLRequest *)request requestQueue:(NSOperationQueue *)requestQueue
{
    return [self initWithRequest:request cacheManager:nil useCacheWhenOffline:NO requestQueue:requestQueue];
}

#pragma mark -

- (void)setRequestQueue:(NSOperationQueue *)requestQueue
{
    _legacyRequestQueue = requestQueue;
}

- (NSOperationQueue *)requestQueue
{
    return _legacyRequestQueue;
}

- (void)setPostProcessor:(RKSimplePostProcessorBlock)postProcessor
{
    _legacyPostProcessor = postProcessor;
    
    [super setPostProcessors:@[ [[RKSimplePostProcessor alloc] initWithBlock:postProcessor] ]];
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
