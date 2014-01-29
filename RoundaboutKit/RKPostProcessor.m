//
//  RKPromisePostProcessor.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/6/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import "RKPostProcessor.h"
#import "RKPossibility.h"
#import "RKURLRequestPromise.h"

#if TARGET_OS_IPHONE
#   import <UIKit/UIKit.h>
#endif /* TARGET_OS_IPHONE */

NSString *const RKPostProcessorBadValueStringRepresentationErrorUserInfoKey = @"RKPostProcessorBadValueStringRepresentationErrorUserInfoKey";
NSString *const RKPostProcessorSourceURLErrorUserInfoKey = @"RKPostProcessorSourceURLErrorUserInfoKey";

@implementation RKPostProcessor

#pragma mark - <NSCopying>

- (id)copyWithZone:(NSZone *)zone
{
    return [self.class new];
}

#pragma mark - Types

- (Class)inputValueType
{
    return Nil; //anything
}

- (Class)outputValueType
{
    return Nil; //anything
}

#pragma mark - Processing

- (void)processInputValue:(id)value inputError:(NSError *)error context:(id)context
{
    self.outputValue = value;
    self.outputError = error;
}

@end

#pragma mark -

@implementation RKSimplePostProcessor

#pragma mark - Lifecycle

- (instancetype)initWithBlock:(RKSimplePostProcessorBlock)block
{
    NSParameterAssert(block);
    
    if((self = [super init])) {
        _block = block;
    }
    
    return self;
}

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma mark - <NSCopying>

- (id)copyWithZone:(NSZone *)zone
{
    return [[self.class alloc] initWithBlock:self.block];
}

#pragma mark - Types

- (Class)inputValueType
{
    return Nil; //anything
}

- (Class)outputValueType
{
    return Nil; //anything
}

#pragma mark - Processing

- (void)processInputValue:(id)value inputError:(NSError *)error context:(id)context
{
    RKPossibility *input;
    if(value)
        input = [[RKPossibility alloc] initWithValue:value];
    else if(error)
        input = [[RKPossibility alloc] initWithError:error];
    else
        input = [[RKPossibility alloc] initEmpty];
    
    RKPossibility *result = self.block(input, context);
    
    if(result.state == kRKPossibilityStateError)
        self.outputError = result.error;
    else if(result.state == kRKPossibilityStateValue)
        self.outputValue = result.value;
}

@end


RKSimplePostProcessorBlock const kRKJSONPostProcessorBlock = ^RKPossibility *(RKPossibility *maybeData, RKURLRequestPromise *request) {
    return [maybeData refineValue:^RKPossibility *(NSData *data) {
        NSError *error = nil;
        id result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if(result) {
            return [[RKPossibility alloc] initWithValue:result];
        } else {
            NSMutableDictionary *userInfoCopy = [[error userInfo] mutableCopy];
            
            NSString *stringRepresentation = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if(stringRepresentation)
                userInfoCopy[RKPostProcessorBadValueStringRepresentationErrorUserInfoKey] = stringRepresentation;
            else
                userInfoCopy[RKPostProcessorBadValueStringRepresentationErrorUserInfoKey] = @"(Malformed data)";
            
            if(request.request.URL)
                userInfoCopy[RKPostProcessorSourceURLErrorUserInfoKey] = request.request.URL;
            
            return [[RKPossibility alloc] initWithError:[NSError errorWithDomain:error.domain
                                                                            code:error.code
                                                                        userInfo:userInfoCopy]];
        }
    }];
};

RKSimplePostProcessorBlock const kRKImagePostProcessorBlock = ^RKPossibility *(RKPossibility *maybeData, RKURLRequestPromise *request) {
    return [maybeData refineValue:^RKPossibility *(NSData *data) {
#if TARGET_OS_IPHONE
        UIImage *image = [[UIImage alloc] initWithData:data];
#else
        NSImage *image = [[NSImage alloc] initWithData:data];
#endif /* TARGET_OS_IPHONE */
        if(image) {
            return [[RKPossibility alloc] initWithValue:image];
        } else {
            return [[RKPossibility alloc] initWithError:[NSError errorWithDomain:RKURLRequestPromiseErrorDomain
                                                                            code:'!img'
                                                                        userInfo:@{NSLocalizedDescriptionKey: @"Could not load image"}]];
        }
    }];
};

RKSimplePostProcessorBlock const kRKPropertyListPostProcessorBlock = ^RKPossibility *(RKPossibility *maybeData, RKURLRequestPromise *request) {
    return [maybeData refineValue:^RKPossibility *(NSData *data) {
        NSError *error = nil;
        id result = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&error];
        if(result) {
            return [[RKPossibility alloc] initWithValue:result];
        } else {
            NSMutableDictionary *userInfoCopy = [[error userInfo] mutableCopy];
            
            NSString *stringRepresentation = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if(stringRepresentation)
                userInfoCopy[RKPostProcessorBadValueStringRepresentationErrorUserInfoKey] = stringRepresentation;
            else
                userInfoCopy[RKPostProcessorBadValueStringRepresentationErrorUserInfoKey] = @"(Malformed data)";
            
            if(request.request.URL)
                userInfoCopy[RKPostProcessorSourceURLErrorUserInfoKey] = request.request.URL;
            
            return [[RKPossibility alloc] initWithError:[NSError errorWithDomain:error.domain
                                                                            code:error.code
                                                                        userInfo:userInfoCopy]];
        }
    }];
};
