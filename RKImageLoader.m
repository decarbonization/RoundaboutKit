//
//  RKImageLoader.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 4/1/13.
//  Copyright (c) 2013 Live Nation Labs. All rights reserved.
//

#if TARGET_OS_IPHONE

#import "RKImageLoader.h"

#import "RKURLRequestPromise.h"
#import "RKFileSystemCacheManager.h"

@interface RKImageLoader ()

///The map that contains the loaded images.
///
///nocopy NSURL => UIImage.
@property (nonatomic) NSMutableDictionary *imageMap;

///The in-memory cache for the image loader.
@property (nonatomic) NSCache *inMemoryCache;

///The URLs known to be invalid to the image loader.
///Used to prevent redundant network requests in a session.
@property (nonatomic) NSMutableSet *knownInvalidURLs;

#pragma mark - Readwrite

@property (nonatomic, readwrite) RKFileSystemCacheManager *cacheManager;

@end

@implementation RKImageLoader

+ (instancetype)sharedImageLoader
{
    static RKImageLoader *sharedImageLoader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedImageLoader = [RKImageLoader new];
    });
    
    return sharedImageLoader;
}

- (id)init
{
    if((self = [super init])) {
        self.imageMap = (__bridge NSMutableDictionary *)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        
        self.cacheManager = [RKFileSystemCacheManager sharedCacheManager];
        self.inMemoryCache = [NSCache new];
        self.inMemoryCache.name = @"com.livenationlabs.libTap.ImageLoader.inMemoryCache";
        
        self.knownInvalidURLs = [NSMutableSet set];
    }
    
    return self;
}

#pragma mark - Image Loading

- (void)loadImagePromise:(RKURLRequestPromise *)imagePromise placeholder:(UIImage *)placeholder intoView:(UIImageView *)imageView completionHandler:(RKImageLoaderCompletionHandler)completionHandler
{
    NSParameterAssert(imageView);
    
    imageView.image = placeholder;
    
    if(imagePromise && ![_knownInvalidURLs containsObject:imagePromise.request.URL]) {
        [[self.imageMap objectForKey:imageView] cancel:nil];
        [self.imageMap removeObjectForKey:imageView];
        
        UIImage *existingImage = [self.inMemoryCache objectForKey:imagePromise.request.URL];
        if(existingImage) {
            imageView.image = existingImage;
            
            return;
        }
        
        //Our dictionary does not actually copy its keys.
        CFDictionarySetValue((__bridge CFMutableDictionaryRef)self.imageMap,
                             (__bridge const void *)imageView,
                             (__bridge const void *)imagePromise);
        
        RKRealize(imagePromise, ^(UIImage *image) {
            imageView.image = image;
            
            UITableViewCell *superCell = RK_TRY_CAST(UITableViewCell, imageView.superview.superview);
            [superCell setNeedsLayout];
            
            [self.inMemoryCache setObject:image forKey:imagePromise.request.URL cost:image.size.width + image.size.height];
            [self.imageMap removeObjectForKey:imageView];
            
            if(completionHandler)
                completionHandler(YES);
        }, ^(NSError *error) {
            [self.knownInvalidURLs addObject:imagePromise.request.URL];
            [self.imageMap removeObjectForKey:imageView];
            
            if(error.code != '!img')
                NSLog(@"Could not load image. %@", error);
            
            if(completionHandler)
                completionHandler(NO);
        });
    }
}

- (void)loadImageAtURL:(NSURL *)url placeholder:(UIImage *)placeholder intoView:(UIImageView *)imageView completionHandler:(RKImageLoaderCompletionHandler)completionHandler
{
    NSParameterAssert(imageView);
    
    NSURLRequest *imageURLRequest = [NSURLRequest requestWithURL:url];
    RKURLRequestPromise *imagePromise = [[RKURLRequestPromise alloc] initWithRequest:imageURLRequest
                                                                        cacheManager:self.cacheManager
                                                                 useCacheWhenOffline:YES
                                                                        requestQueue:[RKBlockPromise defaultBlockPromiseQueue]];
    imagePromise.postProcessor = kRKImagePostProcessorBlock;
    
    [self loadImagePromise:imagePromise placeholder:placeholder intoView:imageView completionHandler:completionHandler];
}

- (void)loadImageAtURL:(NSURL *)url placeholder:(UIImage *)placeholder intoView:(UIImageView *)imageView
{
    [self loadImageAtURL:url placeholder:placeholder intoView:imageView completionHandler:nil];
}

- (void)stopLoadingImagesForView:(UIImageView *)imageView
{
    NSParameterAssert(imageView);
    
    [[self.imageMap objectForKey:imageView] cancel:nil];
    [self.imageMap removeObjectForKey:imageView];
}

@end

#endif /* TARGET_OS_IPHONE */
