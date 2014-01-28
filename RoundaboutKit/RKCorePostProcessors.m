//
//  RKCorePostProcessors.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 1/28/14.
//  Copyright (c) 2014 Roundabout Software, LLC. All rights reserved.
//

#import "RKCorePostProcessors.h"

#import <UIKit/UIKit.h>
#import "RKURLRequestPromise.h"

@implementation RKJSONPostProcessor

- (Class)inputValueType
{
    return [NSData class];
}

- (void)processInputValue:(NSData *)data inputError:(NSError *)error context:(id)context
{
    if(error) {
        self.outputError = error;
        return;
    }
    
    NSError *parseError = nil;
    id result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    if(result) {
        self.outputValue = result;
    } else {
        NSMutableDictionary *userInfoCopy = [[parseError userInfo] mutableCopy];
        
        NSString *stringRepresentation = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if(stringRepresentation)
            userInfoCopy[RKPostProcessorBadValueStringRepresentationErrorUserInfoKey] = stringRepresentation;
        else
            userInfoCopy[RKPostProcessorBadValueStringRepresentationErrorUserInfoKey] = @"(Malformed data)";
        
        if([context isKindOfClass:[RKURLRequestPromise class]])
            userInfoCopy[RKPostProcessorSourceURLErrorUserInfoKey] = ((RKURLRequestPromise *)context).request.URL;
        
        self.outputError = [NSError errorWithDomain:parseError.domain
                                               code:parseError.code
                                           userInfo:userInfoCopy];
    }
}

@end

#pragma mark -

@implementation RKPropertyListPostProcessor

- (Class)inputValueType
{
    return [NSData class];
}

- (void)processInputValue:(NSData *)data inputError:(NSError *)error context:(id)context
{
    if(error) {
        self.outputError = error;
        return;
    }
    
    NSError *parseError = nil;
    id result = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&parseError];
    if(result) {
        self.outputValue = result;
    } else {
        NSMutableDictionary *userInfoCopy = [[parseError userInfo] mutableCopy];
        
        NSString *stringRepresentation = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if(stringRepresentation)
            userInfoCopy[RKPostProcessorBadValueStringRepresentationErrorUserInfoKey] = stringRepresentation;
        else
            userInfoCopy[RKPostProcessorBadValueStringRepresentationErrorUserInfoKey] = @"(Malformed data)";
        
        if([context isKindOfClass:[RKURLRequestPromise class]])
            userInfoCopy[RKPostProcessorSourceURLErrorUserInfoKey] = ((RKURLRequestPromise *)context).request.URL;
        
        self.outputError = [NSError errorWithDomain:parseError.domain
                                               code:parseError.code
                                           userInfo:userInfoCopy];
    }
}

@end

#pragma mark -

@implementation RKImagePostProcessor

- (Class)inputValueType
{
    return [NSData class];
}

- (Class)outputValueType
{
#if TARGET_OS_IPHONE
    return [UIImage class];
#else
    return [NSImage class];
#endif /* TARGET_OS_IPHONE */
}

- (void)processInputValue:(NSData *)data inputError:(NSError *)error context:(id)context
{
    if(error) {
        self.outputError = error;
        return;
    }
    
#if TARGET_OS_IPHONE
    UIImage *image = [[UIImage alloc] initWithData:data];
#else
    NSImage *image = [[NSImage alloc] initWithData:data];
#endif /* TARGET_OS_IPHONE */
    if(image) {
        self.outputValue = image;
    } else {
        self.outputError = [NSError errorWithDomain:RKURLRequestPromiseErrorDomain
                                               code:'!img'
                                           userInfo:@{NSLocalizedDescriptionKey: @"Could not load image"}];
    }
}

@end
