//
//  RKRequestFactory.h
//  Pinna
//
//  Created by Kevin MacWhinnie on 5/31/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RKURLRequestPromiseCacheManager;

///The RKRequestFactory class encapsulates the common logic necessary to create RKURLRequestPromises.
///
///A factory is capable of dispensing properly formed route URLs, NSURLRequests, and RKURLRequestPromises.
///
///RKRequestFactory is not intended to be subclassed.
@interface RKRequestFactory : NSObject

///Initialize the receiver with a given base URL.
///
/// \param  baseURL         The base URL used to construct requests. Required.
/// \param  cacheManager    The cache manager to use for requests.
/// \param  requestQueue    The queue to use for requests. Required.
/// \param  postProcessor   The post processor to use. Optional.
///
/// \result A fully initialized request factory.
///
///This is the designated initializer.
- (id)initWithBaseURL:(NSURL *)baseURL
         cacheManager:(id <RKURLRequestPromiseCacheManager>)cacheManager
         requestQueue:(NSOperationQueue *)requestQueue
        postProcessor:(RKPostProcessorBlock)postProcessor;

#pragma mark - Properties

///The base URL.
@property (readonly, RK_NONATOMIC_IOSONLY) NSURL *baseURL;

///The cache manager to use for requests.
@property (readonly, RK_NONATOMIC_IOSONLY) id <RKURLRequestPromiseCacheManager> cacheManager;

///The queue to use for requests.
@property (readonly, RK_NONATOMIC_IOSONLY) NSOperationQueue *requestQueue;

///The post processor block to use.
@property (readonly, copy, RK_NONATOMIC_IOSONLY) RKPostProcessorBlock postProcessor;

#pragma mark - Dispensing URLs

///Returns a new URL constructed from the receiver's base URL,
///a given path, and a given dictionary of parameters.
///
/// \param  path        The path to use. Required.
/// \param  parameters  The parameters. Keys must be strings and values must be able
///                     to be converted through `RKDictionaryToURLParametersString`. Optional.
///
/// \result A newly constructed URL.
///
/// \seealso(RKDictionaryToURLParametersString)
- (NSURL *)URLWithPath:(NSString *)path parameters:(NSDictionary *)parameters;

#pragma mark - Dispensing NSURLRequests

///Returns a new GET request with a given path and parameters.
///
/// \param  path        The path to use. Required.
/// \param  parameters  The parameters. Keys must be strings and values must be able
///                     to be converted through `RKDictionaryToURLParametersString`. Optional.
///
/// \result A newly constructed URL request.
///
/// \seealso(RKDictionaryToURLParametersString)
- (NSURLRequest *)GETRequestWithPath:(NSString *)path parameters:(NSDictionary *)parameters;

///Returns a new DELETE request with a given path and parameters.
///
/// \param  path        The path to use. Required.
/// \param  parameters  The parameters. Keys must be strings and values must be able
///                     to be converted through `RKDictionaryToURLParametersString`. Optional.
///
/// \result A newly constructed URL request.
///
/// \seealso(RKDictionaryToURLParametersString)
- (NSURLRequest *)DELETERequestWithPath:(NSString *)path parameters:(NSDictionary *)parameters;

#pragma mark -

///Returns a new POST request with a given path and parameters.
///
/// \param  path        The path to use. Required.
/// \param  parameters  The parameters. Keys must be strings and values must be able
///                     to be converted through `RKDictionaryToURLParametersString`. Optional.
/// \param  payload     The payload to use for the PUT request. May be either an NSData instance of a JSON object.
///
/// \result A newly constructed URL request.
///
/// \seealso(RKDictionaryToURLParametersString)
- (NSURLRequest *)POSTRequestWithPath:(NSString *)path parameters:(NSDictionary *)parameters payload:(id)payload;

///Returns a new PUT request with a given path and parameters.
///
/// \param  path        The path to use. Required.
/// \param  parameters  The parameters. Keys must be strings and values must be able
///                     to be converted through `RKDictionaryToURLParametersString`. Optional.
/// \param  payload     The payload to use for the PUT request. May be either an NSData instance of a JSON object.
///
/// \result A newly constructed URL request.
///
/// \seealso(RKDictionaryToURLParametersString)
- (NSURLRequest *)PUTRequestWithPath:(NSString *)path parameters:(NSDictionary *)parameters payload:(id)payload;

#pragma mark - Dispensing RKURLRequestPromises

///Returns a new GET request promise with a given path and parameters.
///
/// \param  path        The path to use. Required.
/// \param  parameters  The parameters. Keys must be strings and values must be able
///                     to be converted through `RKDictionaryToURLParametersString`. Optional.
///
/// \result A newly constructed URL request promise.
///
/// \seealso(RKDictionaryToURLParametersString)
- (RKURLRequestPromise *)GETRequestPromiseWithPath:(NSString *)path parameters:(NSDictionary *)parameters RK_REQUIRE_RESULT_USED;

///Returns a new DELETE request promise with a given path and parameters.
///
/// \param  path        The path to use. Required.
/// \param  parameters  The parameters. Keys must be strings and values must be able
///                     to be converted through `RKDictionaryToURLParametersString`. Optional.
///
/// \result A newly constructed URL request promise.
///
/// \seealso(RKDictionaryToURLParametersString)
- (RKURLRequestPromise *)DELETERequestPromiseWithPath:(NSString *)path parameters:(NSDictionary *)parameters RK_REQUIRE_RESULT_USED;

#pragma mark -

///Returns a new POST request promise with a given path and parameters.
///
/// \param  path        The path to use. Required.
/// \param  parameters  The parameters. Keys must be strings and values must be able
///                     to be converted through `RKDictionaryToURLParametersString`. Optional.
/// \param  payload     The payload to use for the PUT request. May be either an NSData instance of a JSON object.
///
/// \result A newly constructed URL request promise.
///
/// \seealso(RKDictionaryToURLParametersString)
- (RKURLRequestPromise *)POSTRequestPromiseWithPath:(NSString *)path parameters:(NSDictionary *)parameters payload:(id)payload RK_REQUIRE_RESULT_USED;

///Returns a new PUT request promise with a given path and parameters.
///
/// \param  path        The path to use. Required.
/// \param  parameters  The parameters. Keys must be strings and values must be able
///                     to be converted through `RKDictionaryToURLParametersString`. Optional.
/// \param  payload     The payload to use for the PUT request. May be either an NSData instance of a JSON object.
///
/// \result A newly constructed URL request promise.
///
/// \seealso(RKDictionaryToURLParametersString)
- (RKURLRequestPromise *)PUTRequestPromiseWithPath:(NSString *)path parameters:(NSDictionary *)parameters payload:(id)payload RK_REQUIRE_RESULT_USED;

@end
