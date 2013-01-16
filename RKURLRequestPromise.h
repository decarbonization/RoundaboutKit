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

///The error domain used by RKURLRequestPromise.
RK_EXTERN NSString *const RKURLRequestPromiseErrorDomain;

///The key used to embed the affected cache identifier into errors by RKURLRequestPromise.
RK_EXTERN NSString *const RKURLRequestPromiseCacheIdentifierErrorUserInfoKey;

enum {
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
- (NSData *)cachedDataForIdentifier:(NSString *)identifier error:(NSError **)error;

@end

#pragma mark - RKPostProcessorBlock

///The RKPostProcessorBlock functor encapsulates conversion of one type of data into another.
///
///Top level RKPostProcessorBlocks will typically be given an NSData object.
///Blocks chained from this point will be given user-defined objects.
typedef RKPossibility *(^RKPostProcessorBlock)(RKPossibility *maybeData);

///Returns a new block that will be given the result of an earlier block.
///
/// \param  source  The first block that will be invoked. Required.
/// \param  refiner The second block that will be invoked, given the result of `source`. Required.
///
/// \result A new block that encapsulates the actions of invoking the source
///         block and then passing that result to the refiner.
RK_EXTERN_OVERLOADABLE RKPostProcessorBlock RKPostProcessorBlockChain(RKPostProcessorBlock source,
                                                                      RKPostProcessorBlock refiner);

///A post-processor block that takes an NSData object and yields JSON.
RK_EXTERN RKPostProcessorBlock const kRKJSONPostProcessorBlock;

#pragma mark -

///The RKURLRequestPromise class encapsulates a network request.
///
///This class uses Etags to track changes to remote response. When
///server responses do not contain an Etag, then two behaviors can
///occur based on the `.useCacheWhenOffline` property:
///
/// -   If YES, then the cache is unconditionally saved to the disc with
///     a garbage Etag associated with it. This enables the cached
///     response to be used to speed up responses, and to be used when
///     there is no internet connection available.
/// -   If NO, then the cache is completely ignored. This is typically
///     the intended behaviour of servers.
///
@interface RKURLRequestPromise : RKMultiPartPromise

///Initialize the receiver with a given request.
///
/// \param  request                 The request to execute. Required.
/// \param  cacheManager            The cache manager to use. Optional.
/// \param  useCacheWhenOffline     Whether or not to use the cache when the internet connectivity is offline.
/// \param  requestQueue            The queue to execute the request in. Required.
///
/// \result A fully initialized request promise object.
///
///This is the designated initializer.
///
///If `.useCacheWhenOffline` is YES, and the internet connection is inactive, then the
///cache will be loaded, and only the second part of the promise will be called back.
- (id)initWithRequest:(NSURLRequest *)request
         cacheManager:(id <RKURLRequestPromiseCacheManager>)cacheManager
  useCacheWhenOffline:(BOOL)useCacheWhenOffline
         requestQueue:(NSOperationQueue *)requestQueue;

#pragma mark - Properties

///The URL request.
@property (readonly, RK_NONATOMIC_IOSONLY) NSURLRequest *request;

///The queue that the request will be executed on.
///
///This queue should be concurrent.
@property (RK_NONATOMIC_IOSONLY) NSOperationQueue *requestQueue;

///The post processor to invoke on the URL request promise.
///
///The post processor block will always be passed NSData objects.
///The block will be invoked for both cache loads and remote data loads.
///No assumptions should be made about environment in a post processor block.
@property (copy) RKPostProcessorBlock postProcessor;

#pragma mark - Cache

///The cache identifier to use.
///
///This defaults to the absolute string of the request's URL.
@property (copy) NSString *cacheIdentifier;

///The cache manager of the request.
@property (readonly, RK_NONATOMIC_IOSONLY) id <RKURLRequestPromiseCacheManager> cacheManager;

///Whether or not the request can use the cache when the internet connection is offline.
///
///If `.useCacheWhenOffline` is YES, and the internet connection is inactive, then the
///cache will be loaded, and only the second part of the promise will be called back.
///
///This property is ignored if `.cacheManager` is nil.
@property (readonly, RK_NONATOMIC_IOSONLY) BOOL useCacheWhenOffline;

@end

#endif /* RKURLRequestPromise_h */
