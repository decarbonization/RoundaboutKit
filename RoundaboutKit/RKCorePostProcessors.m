//
//  RKCorePostProcessors.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 1/28/14.
//  Copyright (c) 2014 Roundabout Software, LLC. All rights reserved.
//

#import "RKCorePostProcessors.h"

#if TARGET_OS_IPHONE
#   import <UIKit/UIKit.h>
#else
#   import <AppKit/AppKit.h>
#endif /* TARGET_OS_IPHONE */

#import "RKURLRequestPromise.h"

@implementation RKJSONPostProcessor

+ (instancetype)sharedPostProcessor
{
    static RKJSONPostProcessor *sharedPostProcessor = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPostProcessor = [self new];
    });
    
    return sharedPostProcessor;
}

#pragma mark - Types

- (Class)inputValueType
{
    return [NSData class];
}

#pragma mark - Processing

- (id)processValue:(NSData *)data error:(NSError **)outError withContext:(id)context
{
    NSError *parseError = nil;
    id result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    if(result) {
        return result;
    } else {
        NSMutableDictionary *userInfoCopy = [[parseError userInfo] mutableCopy];
        
        NSString *stringRepresentation = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if(stringRepresentation)
            userInfoCopy[RKPostProcessorBadValueStringRepresentationErrorUserInfoKey] = stringRepresentation;
        else
            userInfoCopy[RKPostProcessorBadValueStringRepresentationErrorUserInfoKey] = @"(Malformed data)";
        
        if([context isKindOfClass:[RKURLRequestPromise class]])
            userInfoCopy[RKPostProcessorSourceURLErrorUserInfoKey] = ((RKURLRequestPromise *)context).request.URL;
        
        if(outError) *outError = [NSError errorWithDomain:parseError.domain
                                                     code:parseError.code
                                                 userInfo:userInfoCopy];
        
        return nil;
    }
}

@end

#pragma mark -

@implementation RKPropertyListPostProcessor

+ (instancetype)sharedPostProcessor
{
    static RKPropertyListPostProcessor *sharedPostProcessor = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPostProcessor = [self new];
    });
    
    return sharedPostProcessor;
}

#pragma mark - Types

- (Class)inputValueType
{
    return [NSData class];
}

#pragma mark - Processing

- (id)processValue:(NSData *)data error:(NSError **)outError withContext:(id)context
{
    NSError *parseError = nil;
    id result = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&parseError];
    if(result) {
        return result;
    } else {
        NSMutableDictionary *userInfoCopy = [[parseError userInfo] mutableCopy];
        
        NSString *stringRepresentation = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if(stringRepresentation)
            userInfoCopy[RKPostProcessorBadValueStringRepresentationErrorUserInfoKey] = stringRepresentation;
        else
            userInfoCopy[RKPostProcessorBadValueStringRepresentationErrorUserInfoKey] = @"(Malformed data)";
        
        if([context isKindOfClass:[RKURLRequestPromise class]])
            userInfoCopy[RKPostProcessorSourceURLErrorUserInfoKey] = ((RKURLRequestPromise *)context).request.URL;
        
        if(outError) *outError = [NSError errorWithDomain:parseError.domain
                                                     code:parseError.code
                                                 userInfo:userInfoCopy];
        
        return nil;
    }
}

@end

#pragma mark -

@implementation RKImagePostProcessor

+ (instancetype)sharedPostProcessor
{
    static RKImagePostProcessor *sharedPostProcessor = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPostProcessor = [self new];
    });
    
    return sharedPostProcessor;
}

#pragma mark - Types

- (Class)inputValueType
{
    return [NSData class];
}

#pragma mark - Processing

- (id)processValue:(NSData *)data error:(NSError **)outError withContext:(id)context
{
    
#if TARGET_OS_IPHONE
    UIImage *image = [[UIImage alloc] initWithData:data];
#else
    NSImage *image = [[NSImage alloc] initWithData:data];
#endif /* TARGET_OS_IPHONE */
    if(image) {
        return image;
    } else {
        if(outError) *outError = [NSError errorWithDomain:RKURLRequestPromiseErrorDomain
                                                     code:'!img'
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Could not load image"}];
        return nil;
    }
}

@end

#pragma mark -

@implementation RKSingleValuePostProcessor

- (instancetype)initWithObject:(id)object
{
    if((self = [super init])) {
        _object = object;
    }
    
    return self;
}

#pragma mark -

- (Class)inputValueType
{
    return Nil;
}

#pragma mark -

- (id)processValue:(id)value error:(NSError *__autoreleasing *)outError withContext:(id)context
{
    return _object;
}

@end
