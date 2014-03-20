//
//  RKImageLoader.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 4/1/13.
//  Copyright (c) 2013 Live Nation Labs. All rights reserved.
//

#import "RKImageLoader.h"

#import "RKURLRequestPromise.h"
#import "RKFileSystemCacheManager.h"
#import "RKCorePostProcessors.h"

#define xCGSizeGetArea(size) (size.width * size.height)

@interface RKImageLoader ()

///The map that contains the loaded images.
///
///nocopy NSURL => RKImageType.
@property (nonatomic) NSMutableDictionary *imageMap;

///The in-memory cache for the image loader.
@property (nonatomic) NSCache *inMemoryCache;

///The cache identifiers known to be invalid to the image loader.
///Used to prevent redundant network requests in a session.
@property (nonatomic) NSMutableSet *knownInvalidCacheIdentifiers;

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
        self.imageMap = (__bridge_transfer NSMutableDictionary *)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        
        self.cacheManager = [RKFileSystemCacheManager sharedCacheManager];
        self.inMemoryCache = [NSCache new];
        self.inMemoryCache.name = @"com.roundabout.roundaboutkit.imageloader.inMemoryCache";
        
        self.knownInvalidCacheIdentifiers = [NSMutableSet set];
        
        self.maximumCacheCount = 8;
#if TARGET_OS_IPHONE
        self.maximumCacheableSize = [UIScreen mainScreen].bounds.size;
#else
        self.maximumCacheableSize = CGSizeMake(512.0, 512.0);
#endif /* TARGET_OS_IPHONE */
        
#if TARGET_OS_IPHONE
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidReceiveMemoryWarning:)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
#endif /* TARGET_OS_IPHONE */
    }
    
    return self;
}

#pragma mark - Notifications

#if TARGET_OS_IPHONE
- (void)applicationDidReceiveMemoryWarning:(NSNotification *)notification
{
    [self.inMemoryCache removeAllObjects];
}
#endif /* TARGET_OS_IPHONE */

#pragma mark - Properties

- (void)setMaximumCacheableSize:(CGSize)maximumCacheableSize
{
    _maximumCacheableSize = maximumCacheableSize;
    
    self.inMemoryCache.totalCostLimit = xCGSizeGetArea(maximumCacheableSize) * self.maximumCacheCount;
}

- (void)setMaximumCacheCount:(NSUInteger)maximumCacheCount
{
    self.inMemoryCache.countLimit = maximumCacheCount;
    self.inMemoryCache.totalCostLimit = xCGSizeGetArea(_maximumCacheableSize) * self.maximumCacheCount;
}

- (NSUInteger)maximumCacheCount
{
    return self.inMemoryCache.countLimit;
}

#pragma mark - Image Loading

- (void)loadImagePromise:(RKPromise <RKCancelable> *)imagePromise placeholder:(RKImageType *)placeholder intoView:(RKImageViewType *)imageView completionHandler:(RKImageLoaderCompletionHandler)completionHandler
{
    NSParameterAssert(imageView);
    
    imageView.image = placeholder;
    
    if(imagePromise && ![_knownInvalidCacheIdentifiers containsObject:imagePromise.cacheIdentifier]) {
        [(RKPromise <RKCancelable> *)[self.imageMap objectForKey:imageView] cancel:nil];
        [self.imageMap removeObjectForKey:imageView];
        
        RKImageType *existingImage = [self.inMemoryCache objectForKey:imagePromise.cacheIdentifier];
        if(existingImage) {
            imageView.image = existingImage;
            
            if(completionHandler)
                completionHandler(YES);
            
            return;
        }
        
        //Our dictionary does not actually copy its keys.
        CFDictionarySetValue((__bridge CFMutableDictionaryRef)self.imageMap,
                             (__bridge const void *)imageView,
                             (__bridge const void *)imagePromise);
        
        [imagePromise then:^(RKImageType *image) {
            imageView.image = image;
            
#if TARGET_OS_IPHONE
            UITableViewCell *superCell = RK_CAST_OR_NIL(UITableViewCell, imageView.superview.superview);
            [superCell setNeedsLayout];
#endif /* TARGET_OS_IPHONE */
            
            if(xCGSizeGetArea(image.size) < xCGSizeGetArea(_maximumCacheableSize))
                [self.inMemoryCache setObject:image forKey:imagePromise.cacheIdentifier cost:image.size.width + image.size.height];
            
            [self.imageMap removeObjectForKey:imageView];
            
            if(completionHandler)
                completionHandler(YES);
        } otherwise:^(NSError *error) {
            if(imagePromise.cacheIdentifier)
                [self.knownInvalidCacheIdentifiers addObject:imagePromise.cacheIdentifier];
            [self.imageMap removeObjectForKey:imageView];
            
            if(error.code != kRKErrorCodeNotAnImage)
                RKLogError(@"Could not load image. %@", error);
            
            if(completionHandler)
                completionHandler(NO);
        }];
    }
}

- (void)loadImageAtURL:(NSURL *)url placeholder:(RKImageType *)placeholder intoView:(RKImageViewType *)imageView completionHandler:(RKImageLoaderCompletionHandler)completionHandler
{
    NSParameterAssert(imageView);
    
    NSURLRequest *imageURLRequest = [NSURLRequest requestWithURL:url];
    RKURLRequestPromise *imagePromise = [[RKURLRequestPromise alloc] initWithRequest:imageURLRequest
                                                                     offlineBehavior:kRKURLRequestPromiseOfflineBehaviorUseCacheIfAvailable
                                                                        cacheManager:self.cacheManager];
    [imagePromise addPostProcessor:[RKImagePostProcessor sharedPostProcessor]];
    
    [self loadImagePromise:imagePromise placeholder:placeholder intoView:imageView completionHandler:completionHandler];
}

- (void)loadImageAtURL:(NSURL *)url placeholder:(RKImageType *)placeholder intoView:(RKImageViewType *)imageView
{
    [self loadImageAtURL:url placeholder:placeholder intoView:imageView completionHandler:nil];
}

- (void)stopLoadingImagesForView:(RKImageViewType *)imageView
{
    NSParameterAssert(imageView);
    
    [(RKPromise <RKCancelable> *)[self.imageMap objectForKey:imageView] cancel:nil];
    [self.imageMap removeObjectForKey:imageView];
}

@end
