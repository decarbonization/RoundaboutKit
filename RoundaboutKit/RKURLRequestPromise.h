//
//  RKURLRequestPromise.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/31/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#ifndef RKURLRequestPromise_h
#define RKURLRequestPromise_h 1

#import "RKPromise.h"
#import "RKPostProcessor.h"

@class RKPossibility;

///The error domain used by RKURLRequestPromise.
RK_EXTERN NSString *const RKURLRequestPromiseErrorDomain;

///The corresponding value is the cache identifier used by the original RKURLRequestPromise.
RK_EXTERN NSString *const RKURLRequestPromiseCacheIdentifierErrorUserInfoKey;

///The error codes that will be used in the `RKURLRequestPromiseErrorDomain`.
NS_ENUM(NSInteger, RKURLRequestPromiseErrors) {
    ///The cache cannot be loaded.
    kRKURLRequestPromiseErrorCannotLoadCache = 'nrch',
    
    ///The cache cannot be written.
    kRKURLRequestPromiseErrorCannotWriteCache = 'nwch',
};


///The RKURLRequestPromiseCacheManager protocol outlines the methods and behaviours
///necessary for an object to be used as a cache manager for the RKURLRequestPromise class.
///
///The identifiers passed to a cache manager will be of arbitrary lengths, any cache
///manager that uses the file system should be aware of filename length limits.
///
///Identifiers must not begin with a double underscore, these identifiers are
///reserved for the use of the implementation of the cache manager only.
///
///At the time of writing this documentation, if the cache is determined to be current
///the cache manager takes over for the request promise's underlying connection. As such,
///any errors that occur while reading the cache are propagated back to the realizer,
///and the promise will fail. When the request promise detects errors from the cache manager,
///it will call `-[<RKURLRequestPromiseCacheManager> removeCacheForIdentifier:error]`.
///
/// \seealso(-[<RKURLRequestPromiseCacheManager> removeCacheForIdentifier:error])
@protocol RKURLRequestPromiseCacheManager <NSObject>

///Returns the last recorded revision for a given identifier.
///
///The result of this method is used to determine
///if local cache is out of date with the server.
///
///This method will be called from multiple threads.
- (NSString *)revisionForIdentifier:(NSString *)identifier;

///Persist a given data object with a specified identifier and ETag into the receiver.
///
/// \param  data        The data to persist. May be nil.
/// \param  identifier  The identifier to use to cache the data. Required.
/// \param  revision    The revision to associate with the data-identifier. Inequality of this
///                     value is used to determine whether or not local cache is out of date. Required.
/// \param  error       out NSError.
///
/// \result Whether or not the data could be cached.
///
///This method will be called from multiple threads, and may safely block.
- (BOOL)cacheData:(NSData *)data forIdentifier:(NSString *)identifier withRevision:(NSString *)revision error:(NSError **)error;

///Returns the cached data for a given identifier.
///
/// \param  identifier  The identifier to return the cached data for. Required.
/// \param  error       out NSError.
///
/// \result An NSData object or nil.
///
///This method will be called from multiple threads, and may safely block.
///
///This method should return nil and leave the `out error`
///empty to indicate there is no available value.
- (NSData *)cachedDataForIdentifier:(NSString *)identifier error:(NSError **)error;

///Deletes all cache manager state related to a given identifier.
///
/// \param  identifier  The identifier to delete. Required.
/// \param  outError    out NSError.
///
/// \result Whether or not the cache state could be deleted.
///
///This method is called by `RKURLRequestPromise` when an error
///is returned by the cache manager when the cache manager has
///taken over for the underlying URL connection.
///
///Ideally this method should not fail.
- (BOOL)removeCacheForIdentifier:(NSString *)identifier error:(NSError **)outError;

///Removes all cached values from the receiver.
///
/// \param  outError    out NSError.
///
/// \result YES if the cached values could be removed; NO otherwise.
///
///This method is not directly called by RKURLRequestPromise at the time
///of writing this documentation.
- (BOOL)removeAllCache:(NSError **)outError;

@end

///How an instance of RKURLRequestPromise should behave
///when its connection reports being offline
typedef NS_ENUM(NSUInteger, kRKURLRequestPromiseOfflineBehavior) {
    ///The promise should fail with an error.
    kRKURLRequestPromiseOfflineBehaviorFail = 0,
    
    ///The promise should attempt to use any existing
    ///persistent cache before resorting to failure.
    kRKURLRequestPromiseOfflineBehaviorUseCache = 1,
};

#pragma mark -

@class RKURLRequestPromise;

///The RKURLRequestAuthenticationHandler protocol encapsulates the methods
///required for an object to be an authentication handler for instances of
///the RKURLRequestPromise class.
@protocol RKURLRequestAuthenticationHandler <NSObject>

///Sent to determine whether the handler is able to respond to a protection space's form of authentication.
- (BOOL)request:(RKURLRequestPromise *)sender canHandlerAuthenticateProtectionSpace:(NSURLProtectionSpace *)protectionSpace;

///Sent when a request must authenticate a challenge in order to download its data.
- (void)request:(RKURLRequestPromise *)sender handleAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;

@end

#pragma mark -

@class RKConnectivityManager;
    
///The RKURLRequestPromise class encapsulates a network request. It connects
///with the `RKConnectivityManager` class, comfortably operates with the
///`RKPostProcessor` mechanism from its parent class `RKPromise`, and contains
///a customizable caching system in the form of classes implementing the
///`<RKURLRequestPromiseCacheManager>` protocol.
///
///#Creation:
///
///It is possible to create instances of RKURLRequestPromise directly, however
///it is recommended that all new code is written using `RKRequestFactory`.
///
///#Cache:
///
///RKURLRequestPromise will check headers of responses for an ETag, and if that
///is not found, it will check for a Creation header. If one of said fields are
///found, its value will be used as the revision for the cache manager. Currently
///RKURLRequestPromise does not honor the "Cache-Control" header. __Important:__
///the contents of the "Creation" header are treated as an opaque value, any change
///will result in a full request to the server.
///
///When server headers do not contain cache identification information, there are
///multiple behaviors that can occur depending on the value of `self.offlineBehavior`.
///
/// -   `kRKURLRequestPromiseOfflineBehaviorUseCache`: the cache is unconditionally
///     saved to the disc with an arbitrary revision associated with it. This enables
///     the cached response to be used when there is no internet connection available.
/// -   `kRKURLRequestPromiseOfflineBehaviorFail`: The cache is completely ignored.
///
///#Connectivity:
///
///By default, RKURLRequestPromise will check for connectivity through the
///default internet connection `RKConnectivityManager`. It is possible to
///change the connectivity manager used after a request promise has been
///created by mutating the `self.connectivityManager`.
///
///#Realization:
///
///The RKURLRequestPromise class is lazy. It will not perform any work until
///an attempt is made to observe its realization through one of the available
///methods inherited from `RKPromise`.
@interface RKURLRequestPromise : RKPromise <RKCancelable, RKLazy>

#pragma mark - Logging

///Enables logging of requests starting and completing.
///
///All loggings are run through `RKLogInfo`, as such,
///the appropriate logging type must be enabled.
///
///Errors are always logged regardless of activity logging's state.
+ (void)enableActivityLogging;

///Disables logging of requests starting and completing.
///
///Errors are always logged regardless of activity logging's state.
+ (void)disableActivityLogging;

#pragma mark - Lifecycle

///Initialize the promise with a given URL request. Designated initializer.
///
/// \param  request         The URL request to to run. Required.
/// \param  offlineBehavior How the promise should behave when it detects that there is no connection.
/// \param  cacheManager    The manager to read and write persistent cache to and from.
///
/// \result A fully initialized request-promise ready for use.
///
///__Important:__ Unless a cache manager is provided, `offlineBehavior` must be
///`kRKURLRequestPromiseOfflineBehaviorFail` or an exception will be raised.
///
///It is recommended to use `RKRequestFactory` instead of creating RKURLRequestPromises directly.
- (instancetype)initWithRequest:(NSURLRequest *)request
                offlineBehavior:(kRKURLRequestPromiseOfflineBehavior)offlineBehavior
                   cacheManager:(id <RKURLRequestPromiseCacheManager>)cacheManager RK_REQUIRE_RESULT_USED;

#pragma mark - Properties

///The connectivity manager object used to determine if the receiver is connected to its target.
///
///Defaults to `+[RKConnectivityManager defaultInternetConnectivityManager]`.
///This property is primarily provided for the purposes of testing.
///Assigning nil to this property will raise an exception.
@property (nonatomic) RKConnectivityManager *connectivityManager;

///The URL request.
@property (readonly, RK_NONATOMIC_IOSONLY) NSURLRequest *request;

///The HTTP response received when realizing the request.
///
///This property will be set for any request that is routed through a server.
///This property is not guaranteed to be set when a post-processor is called
///through `-[RKURLRequestPromise loadCachedDataWithCallbackQueue:block:]`.
///Post-processors should take this into account.
@property (copy, readonly) NSHTTPURLResponse *response;

#pragma mark -

///The authentication handler of the request promise.
@property (RK_NONATOMIC_IOSONLY) id <RKURLRequestAuthenticationHandler> authenticationHandler;

#pragma mark - Cache

///The cache manager of the request.
@property (readonly, RK_NONATOMIC_IOSONLY) id <RKURLRequestPromiseCacheManager> cacheManager;

#pragma mark -

///How the request promise should behave if its connectivity manager reports being offline.
///
/// \seealso(kRKURLRequestPromiseOfflineBehavior)
@property (readonly, RK_NONATOMIC_IOSONLY) kRKURLRequestPromiseOfflineBehavior offlineBehavior;

///Whether or not the request should cancel itself if it finds
///its cache is unchanged from the newly loaded remote data.
@property (RK_NONATOMIC_IOSONLY) BOOL cancelWhenRemoteDataUnchanged;

#pragma mark -

///Returns a new promise for any cached data available for the request described by the receiver.
///
/// \result A new promise object that will propagate any cached data available.
///
///The returned promise will use the same post-processors that
///the receiver has at the time this method is invoked.
- (RKPromise *)cachedData RK_REQUIRE_RESULT_USED;

@end

#pragma mark - Deprecated

///The older name for blocks of type `RKLegacyPostProcessorBlock`. Deprecated
///
/// \seealso(RKLegacyPostProcessorBlock)
typedef RKLegacyPostProcessorBlock RKPostProcessorBlock DEPRECATED_ATTRIBUTE;

///Returns a new block that will be given the result of an earlier block.
///
/// \param  source  The first block that will be invoked. Required.
/// \param  refiner The second block that will be invoked, given the result of `source`. Required.
///
/// \result A new block that encapsulates the actions of invoking the source
///         block and then passing that result to the refiner.
///
///This function is deprecated. Use an array of independent post-processors instead.
RK_EXTERN_OVERLOADABLE RKLegacyPostProcessorBlock RKPostProcessorBlockChain(RKLegacyPostProcessorBlock source,
                                                                            RKLegacyPostProcessorBlock refiner) DEPRECATED_ATTRIBUTE;

#pragma mark -

///The methods deprecated in RKURLRequestPromise slated for removal in the near future.
@interface RKURLRequestPromise (RKDeprecated)

///__Deprecated__. Use `[self initWithRequest:offlineBehavior:cacheManager:]` instead.
///
///Initialize the receiver with a given request.
///
/// \param  request                 The request to execute. Required.
/// \param  cacheManager            The cache manager to use. Optional.
/// \param  useCacheWhenOffline     Whether or not to use the cache when the internet connectivity is offline.
/// \param  requestQueue            The queue to execute the request in. Required.
///
/// \result A fully initialized request promise object.
///
///If `.useCacheWhenOffline` is YES, and the internet connection is inactive, then the
///cache will be loaded, and only the second part of the promise will be called back.
///
///__Important:__ Starting in RK 2.1, RKURLRequestPromise has a new designated initializer
///that does not take an operation queue. This interface should be preferred as it allows
///RKURLRequestPromise to respond better to changes in external conditions. This method
///and its associated short hands will be removed in the future.
- (id)initWithRequest:(NSURLRequest *)request
         cacheManager:(id <RKURLRequestPromiseCacheManager>)cacheManager
  useCacheWhenOffline:(BOOL)useCacheWhenOffline
         requestQueue:(NSOperationQueue *)requestQueue RK_REQUIRE_RESULT_USED DEPRECATED_ATTRIBUTE;

///Deprecated. See `[self initWithRequest:offlineBehavior:cacheManager:]`.
- (id)initWithRequest:(NSURLRequest *)request
         cacheManager:(id <RKURLRequestPromiseCacheManager>)cacheManager
         requestQueue:(NSOperationQueue *)requestQueue RK_REQUIRE_RESULT_USED DEPRECATED_ATTRIBUTE;

///Deprecated. See `[self initWithRequest:offlineBehavior:cacheManager:]`.
- (id)initWithRequest:(NSURLRequest *)request requestQueue:(NSOperationQueue *)requestQueue RK_REQUIRE_RESULT_USED DEPRECATED_ATTRIBUTE;

#pragma mark -

///_Deprecated._ The queue that all asynchronous work related to the networking request will be run on.
///
///Starting in RK 2.1, RKURLRequestPromise provides its own work queue.
///This allows it to better adapt to changes in external conditions.
///If a queue is provided through one of the legacy deprecated initializers,
///it will be used over the new internal queue. Clients should migrate away
///from relying on external queues as soon as possible.
@property (RK_NONATOMIC_IOSONLY) NSOperationQueue *requestQueue DEPRECATED_ATTRIBUTE;

///The post processor to invoke on the URL request promise.
///This is the legacy interface for post-processors. Use
///`-[RKPromise addPostProcessor:]` instead.
///
///__Important:__ Starting in RK 2.1, setting this property
///when a URL request promise has already been realized will
///raise an exception. Additionally, this property is no
///longer atomic.
///
///This property is mutually exclusive with the modern post-
///processor system. Setting this property will wipe out
///any post-processors attached to the promise, and attempting
///to add a post-processor through `-[RKPromise addPostProcessor:]`
///will raise if this property is not nil.
@property (nonatomic, copy) RKLegacyPostProcessorBlock postProcessor DEPRECATED_ATTRIBUTE;

@end

#endif /* RKURLRequestPromise_h */
