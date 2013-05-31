//
//  RKURLRequestPromiseCacheManager.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 1/7/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import "RKURLRequestPromiseCacheManager.h"
#import <CommonCrypto/CommonDigest.h>

@interface RKURLRequestPromiseCacheManager ()

///Readwrite
@property (readwrite, copy) NSString *bucketName;

@end

@implementation RKURLRequestPromiseCacheManager {
    NSURL *_bucketLocation;
    NSURL *_metadataLocation;
    
    dispatch_queue_t _accessQueue;
    NSMutableDictionary *_metadata;
}

#pragma mark - Locations

///Returns the location of the cache manager's directory.
+ (NSURL *)cachesLocation
{
    NSError *error = nil;
    NSURL *cachesLocation = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory
                                                                   inDomain:NSUserDomainMask
                                                          appropriateForURL:nil
                                                                     create:YES
                                                                      error:&error];
    NSAssert(cachesLocation != nil, @"Could not find caches directory. %@", error);
    return [[cachesLocation URLByAppendingPathComponent:[[NSBundle bundleForClass:[self class]] bundleIdentifier]] URLByAppendingPathComponent:@"RKURLRequestPromiseCache"];
}

///Returns the location of a bucket with a given name.
+ (NSURL *)locationForBucket:(NSString *)bucketName
{
    NSParameterAssert(bucketName);
    
    return [[self cachesLocation] URLByAppendingPathComponent:bucketName];
}

///Returns the location of a bucket's metadata file.
+ (NSURL *)locationForMetadataInBucket:(NSString *)bucketName
{
    return [[self locationForBucket:bucketName] URLByAppendingPathComponent:@"__Metadata.plist"];
}

#pragma mark - Lifecycle

+ (NSMutableDictionary *)sharedInstances
{
    static NSMutableDictionary *sharedInstances = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstances = [NSMutableDictionary new];
    });
    
    return sharedInstances;
}

+ (RKURLRequestPromiseCacheManager *)sharedCacheManagerForBucket:(NSString *)bucketName
{
    NSParameterAssert(bucketName);
    
    NSMutableDictionary *sharedInstances = [self sharedInstances];
    @synchronized(sharedInstances) {
        RKURLRequestPromiseCacheManager *cacheManager = sharedInstances[bucketName];
        if(!cacheManager) {
            cacheManager = [[RKURLRequestPromiseCacheManager alloc] initWithBucket:bucketName];
            sharedInstances[bucketName] = cacheManager;
        }
        return cacheManager;
    }
}

#pragma mark -

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithBucket:(NSString *)bucketName
{
    NSParameterAssert(bucketName);
    
    if((self = [super init])) {
        _accessQueue = dispatch_queue_create("com.roundabout.RoundaboutKit.RKURLRequestPromiseCacheManager.accessQueue", 0);
        dispatch_barrier_async(_accessQueue, ^{
            _bucketLocation = [[self class] locationForBucket:bucketName];
            if(![_bucketLocation checkResourceIsReachableAndReturnError:nil]) {
                NSError *error = nil;
                if(![[NSFileManager defaultManager] createDirectoryAtURL:_bucketLocation
                                             withIntermediateDirectories:YES
                                                              attributes:nil
                                                                   error:&error]) {
                    [NSException raise:NSInternalInconsistencyException format:@"Could not create bucket location %@. %@", _bucketLocation, error];
                }
            }
            
            _metadataLocation = [[self class] locationForMetadataInBucket:bucketName];
            _metadata = [NSMutableDictionary dictionaryWithContentsOfURL:_metadataLocation] ?: [NSMutableDictionary dictionary];
            
            self.bucketName = bucketName;
        });
    }
    
    return self;
}

#pragma mark - Sanitizing Identifiers

///Returns the sanitized form of an identifier.
- (NSString *)sanitizedIdentifier:(NSString *)identifier
{
    NSParameterAssert(identifier);
    
    return RKStringGetMD5Hash(identifier);
}

#pragma mark - Metadata

///Writes the metadata dictionary to the file system.
- (void)synchronizeMetadata
{
    [_metadata writeToURL:_metadataLocation atomically:YES];
}

#pragma mark - <RKURLRequestPromiseCacheManager>

- (NSString *)revisionForIdentifier:(NSString *)identifier
{
    NSParameterAssert(identifier);
    
    __block NSString *revision = nil;
    dispatch_sync(_accessQueue, ^{
        NSString *sanitizedIdentifier = [self sanitizedIdentifier:identifier];
        revision = _metadata[sanitizedIdentifier][@"revision"];
    });
    
    return revision;
}

- (BOOL)cacheData:(NSData *)data forIdentifier:(NSString *)identifier withRevision:(NSString *)revision error:(NSError **)error
{
    NSParameterAssert(identifier);
    NSParameterAssert(revision);
    
    __block BOOL success = YES;
    dispatch_barrier_sync(_accessQueue, ^{
        NSString *sanitizedIdentifier = [self sanitizedIdentifier:identifier];
        NSURL *dataLocation = [_bucketLocation URLByAppendingPathComponent:sanitizedIdentifier];
        
        if([data writeToURL:dataLocation options:NSAtomicWrite error:error]) {
            _metadata[sanitizedIdentifier] = @{@"revision": revision};
            [self synchronizeMetadata];
        } else {
            success = NO;
        }
    });
    
    return success;
}

- (NSData *)cachedDataForIdentifier:(NSString *)identifier error:(NSError **)outError
{
    NSParameterAssert(identifier);
    
    __block NSError *error = nil;
    __block NSData *data = nil;
    dispatch_sync(_accessQueue, ^{
        NSString *sanitizedIdentifier = [self sanitizedIdentifier:identifier];
        NSURL *dataLocation = [_bucketLocation URLByAppendingPathComponent:sanitizedIdentifier];
        data = [NSData dataWithContentsOfURL:dataLocation options:0 error:&error];
    });
    
    if(data) {
        return data;
    } else {
        if(error.code == NSFileReadNoSuchFileError) {
            return nil;
        } else {
            if(outError) *outError = error;
            return nil;
        }
    }
}

- (BOOL)removeCacheForIdentifier:(NSString *)identifier error:(NSError **)outError
{
    NSParameterAssert(identifier);
    
    __block BOOL success = YES;
    __block NSError *error = nil;
    dispatch_barrier_sync(_accessQueue, ^{
        NSString *sanitizedIdentifier = [self sanitizedIdentifier:identifier];
        NSURL *dataLocation = [_bucketLocation URLByAppendingPathComponent:sanitizedIdentifier];
        
        if([[NSFileManager defaultManager] removeItemAtURL:dataLocation error:&error] || error.code == NSFileNoSuchFileError) {
            [_metadata removeObjectForKey:sanitizedIdentifier];
            [self synchronizeMetadata];
            
            error = nil;
        } else {
            success = NO;
        }
    });
    
    if(outError) *outError = error;
    
    return success;
}

- (BOOL)removeAllCache:(NSError **)outError
{
    __block BOOL success = YES;
    __block NSError *error = nil;
    dispatch_barrier_sync(_accessQueue, ^{
        if([[NSFileManager defaultManager] removeItemAtURL:_bucketLocation error:&error] || error.code == NSFileNoSuchFileError) {
            [_metadata removeAllObjects];
            [self synchronizeMetadata];
            
            error = nil;
        } else {
            success = NO;
        }
    });
    
    if(outError) *outError = error;
    
    return success;
}

@end
