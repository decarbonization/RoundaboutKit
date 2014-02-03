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
#import "RKCorePostProcessors.h"

#if TARGET_OS_IPHONE
#   import <UIKit/UIKit.h>
#endif /* TARGET_OS_IPHONE */

NSString *const RKPostProcessorBadValueStringRepresentationErrorUserInfoKey = @"RKPostProcessorBadValueStringRepresentationErrorUserInfoKey";
NSString *const RKPostProcessorSourceURLErrorUserInfoKey = @"RKPostProcessorSourceURLErrorUserInfoKey";

@implementation RKPostProcessor

#pragma mark - Types

- (Class)inputValueType
{
    return Nil;
}

#pragma mark - Processing

- (id)processValue:(id)value error:(NSError **)outError withContext:(id)context
{
    return value;
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

#pragma mark - Types

- (Class)inputValueType
{
    return Nil; //anything
}

#pragma mark - Processing

- (id)processValue:(id)value error:(NSError **)outError withContext:(id)context
{
    RKPossibility *input;
    if(value)
        input = [[RKPossibility alloc] initWithValue:value];
    else
        input = [[RKPossibility alloc] initEmpty];
    
    RKPossibility *result = self.block(input, context);
    
    if(result.state == kRKPossibilityStateError) {
        if(outError) *outError = result.error;
        return nil;
    } else {
        return result.value;
    }
}

@end


RKSimplePostProcessorBlock const kRKJSONPostProcessorBlock = ^RKPossibility *(RKPossibility *maybeData, RKURLRequestPromise *request) {
    if(maybeData.state == kRKPossibilityStateValue) {
        NSError *error = nil;
        id value = [[RKJSONPostProcessor sharedPostProcessor] processValue:maybeData.value error:&error withContext:request];
        if(error)
            return [[RKPossibility alloc] initWithError:error];
        else if(value)
            return [[RKPossibility alloc] initWithValue:value];
        else
            return [[RKPossibility alloc] initEmpty];
    } else {
        return maybeData;
    }
};

RKSimplePostProcessorBlock const kRKImagePostProcessorBlock = ^RKPossibility *(RKPossibility *maybeData, RKURLRequestPromise *request) {
    if(maybeData.state == kRKPossibilityStateValue) {
        NSError *error = nil;
        id value = [[RKImagePostProcessor sharedPostProcessor] processValue:maybeData.value error:&error withContext:request];
        if(error)
            return [[RKPossibility alloc] initWithError:error];
        else if(value)
            return [[RKPossibility alloc] initWithValue:value];
        else
            return [[RKPossibility alloc] initEmpty];
    } else {
        return maybeData;
    }
};

RKSimplePostProcessorBlock const kRKPropertyListPostProcessorBlock = ^RKPossibility *(RKPossibility *maybeData, RKURLRequestPromise *request) {
    if(maybeData.state == kRKPossibilityStateValue) {
        NSError *error = nil;
        id value = [[RKPropertyListPostProcessor sharedPostProcessor] processValue:maybeData.value error:&error withContext:request];
        if(error)
            return [[RKPossibility alloc] initWithError:error];
        else if(value)
            return [[RKPossibility alloc] initWithValue:value];
        else
            return [[RKPossibility alloc] initEmpty];
    } else {
        return maybeData;
    }
};
