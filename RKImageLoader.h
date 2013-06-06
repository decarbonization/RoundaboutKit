//
//  RKImageLoader.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 4/1/13.
//  Copyright (c) 2013 Live Nation Labs. All rights reserved.
//

#if TARGET_OS_IPHONE

#import <UIKit/UIKit.h>

@class RKFileSystemCacheManager;

///A block which is invoked as a callback for an image loader.
typedef void(^RKImageLoaderCompletionHandler)(BOOL wasSuccessful);

///The RKImageLoader class encapsulates the asynchronous loading of images for libTap.
@interface RKImageLoader : NSObject

///Returns the shared image loader, creating it if it does not already exist.
+ (instancetype)sharedImageLoader;

#pragma mark - Properties

///The cache manager for the image loader.
@property (nonatomic, readonly) RKFileSystemCacheManager *cacheManager;

#pragma mark - Loading Images

///Asynchronously load a URL request promise into a specified image view.
///
/// \param  imagePromise    The image promise to load.
/// \param  placeholder     The placeholder to use while the image is loading.
/// \param  imaceView       The image view to load the image into. Required.
/// \param  completionHandler   The completion handler to invoke when the image is loaded.
///
///If `imagePromise` is nil, this method simply sets `imageView`'s `image` to `placeholder`.
///
///This is the primitive loading method of RKImageLoader.
- (void)loadImagePromise:(RKURLRequestPromise *)imagePromise placeholder:(UIImage *)placeholder intoView:(UIImageView *)imageView completionHandler:(RKImageLoaderCompletionHandler)completionHandler;

///Asynchronously load an image at a given URL into a specified image view.
///
/// \param  url                 The url of the image to load.
/// \param  placeholder         The placeholder to use while the image is loading.
/// \param  imageView           The image view to load the image into. Required.
/// \param  completionHandler   The completion handler to invoke when the image is loaded.
///
///If `url` is nil, this method simply sets `imageView`'s `image` to `placeholder`.
- (void)loadImageAtURL:(NSURL *)url placeholder:(UIImage *)placeholder intoView:(UIImageView *)imageView completionHandler:(RKImageLoaderCompletionHandler)completionHandler;

/// \seealso(-[self loadImageAtURL:placeholder:intoView:completionHandler:)
- (void)loadImageAtURL:(NSURL *)url placeholder:(UIImage *)placeholder intoView:(UIImageView *)imageView;

///Stops all asynchronous image loads currently being executed for a specified image view.
- (void)stopLoadingImagesForView:(UIImageView *)imageView;

@end

#endif /* TARGET_OS_IPHONE */
