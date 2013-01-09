//
//  RKURLRequestPromise.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/31/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#import "RKURLRequestPromise.h"
#import "RKReachability.h"

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

///The first on success callback block.
@property (copy, RK_NONATOMIC_IOSONLY) RKMultiPartPromiseFirstSuccessBlock onFirstSuccess;

///The second on success callback block.
@property (copy, RK_NONATOMIC_IOSONLY) RKMultiPartPromiseSecondSuccessBlock onSecondSuccess;

///The on failure callback block.
@property (copy, RK_NONATOMIC_IOSONLY) RKMultiPartPromiseFailureBlock onFailure;

///The queue to invoke the callback blocks on.
@property (RK_NONATOMIC_IOSONLY) NSOperationQueue *callbackQueue;

#pragma mark -

@property (copy, RK_NONATOMIC_IOSONLY) NSDictionary *responseHeaderFields;

///The underlying connection.
@property NSURLConnection *connection;

#pragma mark - Readwrite Properties

///Readwrite
@property (readwrite, RK_NONATOMIC_IOSONLY) NSURLRequest *request;

///Readwrite
@property (readwrite, RK_NONATOMIC_IOSONLY) id <RKURLRequestPromiseCacheManager> cacheManager;

///Readwrite
@property (readwrite, RK_NONATOMIC_IOSONLY) BOOL useCacheWhenOffline;

///Readwrite
@property (readwrite, RK_NONATOMIC_IOSONLY) NSOperationQueue *requestQueue;

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

- (void)executeWithFirstSuccessBlock:(RKMultiPartPromiseFirstSuccessBlock)onFirstSuccess
                  secondSuccessBlock:(RKMultiPartPromiseSecondSuccessBlock)onSecondSuccess
                        failureBlock:(RKMultiPartPromiseFailureBlock)onFailure
                       callbackQueue:(NSOperationQueue *)callbackQueue
{
    NSParameterAssert(onFirstSuccess);
    NSParameterAssert(onSecondSuccess);
    NSParameterAssert(onFailure);
    NSParameterAssert(callbackQueue);
    
    NSAssert((self.connection == nil),
             @"Cannot realize a %@ more than once.", NSStringFromClass([self class]));
    
    self.onFirstSuccess = onFirstSuccess;
    self.onSecondSuccess = onSecondSuccess;
    self.onFailure = onFailure;
    self.callbackQueue = callbackQueue;
    
    _loadedData = [NSMutableData new];
    
    _isInOfflineMode = ![RKReachability defaultInternetConnectionReachability].isConnected;
    
    [self loadCache];
    
    if(!_isInOfflineMode) {
        self.connection = [[NSURLConnection alloc] initWithRequest:self.request
                                                          delegate:self
                                                  startImmediately:NO];
        
        [self.connection setDelegateQueue:self.requestQueue];
        [self.connection start];
    }
}

- (void)cancel:(id)sender
{
    [super cancel:nil];
    
    [self.connection cancel];
    _loadedData = nil;
}

- (void)loadCache
{
    if(!self.cacheManager || self.cancelled || self.cacheIdentifier == nil)
        return;
    
    [self.requestQueue addOperationWithBlock:^{
        NSError *error = nil;
        NSData *data = [self.cacheManager cachedDataForIdentifier:self.cacheIdentifier error:&error];
        if(data) {
            if(_isInOfflineMode) {
                [self invokeSecondSuccessCallbackWithData:data];
            } else {
                [self invokeFirstSuccessCallbackWithData:data];
            }
        } else {
            NSDictionary *userInfo = @{
                NSUnderlyingErrorKey: error,
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not load cached data for identifier %@.", self.cacheIdentifier],
                RKURLRequestPromiseCacheIdentifierErrorUserInfoKey: self.cacheIdentifier,
            };
            NSError *highLevelError = [NSError errorWithDomain:RKURLRequestPromiseErrorDomain
                                                          code:kRKURLRequestPromiseErrorCannotLoadCache
                                                      userInfo:userInfo];
            if(_isInOfflineMode) {
                [self invokeFailureCallbackWithError:highLevelError fromPart:kRKMultiPartPromisePartSecond];
            } else {
                [self invokeFailureCallbackWithError:highLevelError fromPart:kRKMultiPartPromisePartFirst];
            }
        }
    }];
}

#pragma mark - Invoking Callbacks

- (void)invokeFirstSuccessCallbackWithData:(NSData *)data
{
    if(self.cancelled)
        return;
    
    [self.callbackQueue addOperationWithBlock:^{
        if(self.postProcessor) {
            RKPossibility *maybeValue = self.postProcessor([[RKPossibility alloc] initWithValue:data]);
            if(maybeValue.state == kRKPossibilityStateError) {
                self.onFailure(maybeValue.error, kRKMultiPartPromisePartFirst);
            } else {
                self.onFirstSuccess(maybeValue.value, YES);
            }
        } else {
            self.onFirstSuccess(data, YES);
        }
    }];
}

- (void)invokeSecondSuccessCallbackWithData:(NSData *)data
{
    if(self.cancelled)
        return;
    
    [self.callbackQueue addOperationWithBlock:^{
        if(self.postProcessor) {
            RKPossibility *maybeValue = self.postProcessor([[RKPossibility alloc] initWithValue:data]);
            if(maybeValue.state == kRKPossibilityStateError) {
                self.onFailure(maybeValue.error, kRKMultiPartPromisePartSecond);
            } else {
                self.onSecondSuccess(maybeValue.value);
            }
        } else {
            self.onSecondSuccess(data);
        }
    }];
}

- (void)invokeFailureCallbackWithError:(NSError *)error fromPart:(RKMultiPartPromisePart)part
{
    if(self.cancelled)
        return;
    
    [self.callbackQueue addOperationWithBlock:^{
        self.onFailure(error, part);
    }];
}

#pragma mark - <NSURLConnectionDelegate>

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self invokeFailureCallbackWithError:error fromPart:kRKMultiPartPromisePartSecond];
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
        _loadedData = nil;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [_loadedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if(self.cancelled)
        return;
    
    if(self.cacheManager) {
        NSString *etag = self.responseHeaderFields[kETagHeaderKey];
        if(!etag && self.useCacheWhenOffline)
            etag = kDefaultETagKey;
        
        if(etag) {
            NSError *error = nil;
            if(![self.cacheManager cacheData:_loadedData
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
                [self invokeFailureCallbackWithError:highLevelError fromPart:kRKMultiPartPromisePartFirst];
            }
        }
    }
    
    [self invokeSecondSuccessCallbackWithData:_loadedData];
    
    _loadedData = nil;
}

@end
