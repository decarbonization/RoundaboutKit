//
//  RKRequestFactory.h
//  Pinna
//
//  Created by Kevin MacWhinnie on 5/31/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RKPostProcessor.h"

@protocol RKURLRequestPromiseCacheManager, RKURLRequestAuthenticationHandler;
@class RKURLRequestPromise;

///The different possible types of POST/PUT body types.
typedef NS_ENUM(NSUInteger, RKRequestFactoryBodyType) {
    ///The body is raw data.
    kRKRequestFactoryBodyTypeData = 0,
    
    ///The body is a dictionary that should be interpreted as URL parameters.
    kRKRequestFactoryBodyTypeURLParameters = 1,
    
    ///The body is a JSON object.
    kRKRequestFactoryBodyTypeJSON = 2,
};

///The RKRequestFactory class encapsulates the common logic necessary to create RKURLRequestPromises.
///
///A factory is capable of dispensing properly formed route URLs, NSURLRequests, and RKURLRequestPromises.
///
///A request factory contains two cache managers. One used exclusively for GET requests (the read manager),
///and one used for POST, and PUT requests (the write manager). This is done with the belief that
///caching behaviour will likely vary in clients between reading and writing requests.
///
///RKRequestFactory is not intended to be subclassed.
@interface RKRequestFactory : NSObject

///Initialize the receiver with the objects required to operate.
///
/// \param  baseURL             The base URL to combine with routes to construct requests. Required.
/// \param  readCacheManager    The cache manager to use for GET requests. May be nil.
/// \param  writeCacheManager   The cache manager to use for POST and PUT requests. May be nil.
/// \param  postProcessors      An array of post-processors to apply to each vended request. May be nil.
///
/// \result A fully initialized request factory ready for use.
///
///This is the designated initializer
- (instancetype)initWithBaseURL:(NSURL *)baseURL
               readCacheManager:(id <RKURLRequestPromiseCacheManager>)readCacheManager
              writeCacheManager:(id <RKURLRequestPromiseCacheManager>)writeCacheManager
                 postProcessors:(NSArray *)postProcessors;

///Cannot initialize a request factory without input objects.
///Use `-[self initWithBaseURL:readCacheMaanger:writeCacheManager:requestQueue:postProcessors:]`.
- (id)init UNAVAILABLE_ATTRIBUTE;

#pragma mark - Properties

///The base URL.
@property (readonly, RK_NONATOMIC_IOSONLY) NSURL *baseURL;

///The cache manager to use for GET requests.
@property (readonly, RK_NONATOMIC_IOSONLY) id <RKURLRequestPromiseCacheManager> readCacheManager;

///The cache manager to use for POST, PUT, and DELETE requests.
@property (readonly, RK_NONATOMIC_IOSONLY) id <RKURLRequestPromiseCacheManager> writeCacheManager;

///The post processors to use for vended requests.
@property (readonly, copy, RK_NONATOMIC_IOSONLY) NSArray *postProcessors;

#pragma mark -

///The authentication handler to use for requests.
@property (strong, RK_NONATOMIC_IOSONLY) id <RKURLRequestAuthenticationHandler> authenticationHandler;

///The stringifier to use when serializing dictionaries into URL parameter strings.
///
///Defaults to `kRKURLParameterStringifierDefault`. This property may not be nil.
@property (copy, RK_NONATOMIC_IOSONLY) RKURLParameterStringifier URLParameterStringifier;

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
/// \seealso(RKDictionaryToURLParametersString, self.URLParameterStringifier)
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
/// \param  body     The body to use for the POST request. This value will be interpreted according to the value of bodyType.
/// \param  bodyType How the body parameter should be interpreted.
///
/// \result A newly constructed URL request.
///
/// \seealso(RKDictionaryToURLParametersString, RKRequestFactoryBodyType, self.URLParameterStringifier)
- (NSURLRequest *)POSTRequestWithPath:(NSString *)path parameters:(NSDictionary *)parameters body:(id)body bodyType:(RKRequestFactoryBodyType)bodyType;

///Returns a new PUT request with a given path and parameters.
///
/// \param  path        The path to use. Required.
/// \param  parameters  The parameters. Keys must be strings and values must be able
///                     to be converted through `RKDictionaryToURLParametersString`. Optional.
/// \param  body     The body to use for the POST request. This value will be interpreted according to the value of bodyType.
/// \param  bodyType How the body parameter should be interpreted.
///
/// \result A newly constructed URL request.
///
/// \seealso(RKDictionaryToURLParametersString, RKRequestFactoryBodyType, self.URLParameterStringifier)
- (NSURLRequest *)PUTRequestWithPath:(NSString *)path parameters:(NSDictionary *)parameters body:(id)body bodyType:(RKRequestFactoryBodyType)bodyType;

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
/// \param  body     The body to use for the POST request. This value will be interpreted according to the value of bodyType.
/// \param  bodyType How the body parameter should be interpreted.
///
/// \result A newly constructed URL request promise.
///
/// \seealso(RKDictionaryToURLParametersString, RKRequestFactoryBodyType)
- (RKURLRequestPromise *)POSTRequestPromiseWithPath:(NSString *)path
                                         parameters:(NSDictionary *)parameters
                                               body:(id)body
                                           bodyType:(RKRequestFactoryBodyType)bodyType RK_REQUIRE_RESULT_USED;

///Returns a new PUT request promise with a given path and parameters.
///
/// \param  path        The path to use. Required.
/// \param  parameters  The parameters. Keys must be strings and values must be able
///                     to be converted through `RKDictionaryToURLParametersString`. Optional.
/// \param  body     The body to use for the PUT request. This value will be interpreted according to the value of bodyType.
/// \param  bodyType How the body parameter should be interpreted.
///
/// \result A newly constructed URL request promise.
///
/// \seealso(RKDictionaryToURLParametersString, RKRequestFactoryBodyType)
- (RKURLRequestPromise *)PUTRequestPromiseWithPath:(NSString *)path
                                        parameters:(NSDictionary *)parameters
                                              body:(id)body
                                          bodyType:(RKRequestFactoryBodyType)bodyType RK_REQUIRE_RESULT_USED;

@end

#pragma mark -

///The deprecated legacy methods of RKRequestFactory
///that will be removed in the near future.
@interface RKRequestFactory (RKDeprecatedMethods)

///Obsolete. Use `-[self initWithBaseURL:readCacheMaanger:writeCacheManager:requestQueue:postProcessors:]`.
///
///This method is deprecated and will be removed in the near future.
- (id)initWithBaseURL:(NSURL *)baseURL
     readCacheManager:(id <RKURLRequestPromiseCacheManager>)readCacheManager
    writeCacheManager:(id <RKURLRequestPromiseCacheManager>)writeCacheManager
         requestQueue:(NSOperationQueue *)requestQueue
        postProcessor:(RKSimplePostProcessorBlock)postProcessor RK_DEPRECATED_SINCE_2_1;
///The post processor block to use.
///This is the legacy interface for post-processors.
///Switch to using `self.postProcessors`.
///
///__Important:__ This property is provided as a compatibility shim,
///and is only guaranteed to work if you use the legacy initializer
///`-[self initWithBaseURL:readCacheMaanger:writeCacheManager:requestQueue:postProcessor:]`.
///This property is deprecated and will be removed in the near future.
@property (readonly, copy, RK_NONATOMIC_IOSONLY) RKSimplePostProcessorBlock postProcessor RK_DEPRECATED_SINCE_2_1;

///The queue to use for requests.
@property (readonly, RK_NONATOMIC_IOSONLY) NSOperationQueue *requestQueue RK_DEPRECATED_SINCE_2_1;

@end
