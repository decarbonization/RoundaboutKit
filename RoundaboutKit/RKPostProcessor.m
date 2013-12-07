//
//  RKPromisePostProcessor.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/6/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import "RKPostProcessor.h"
#import "RKPossibility.h"

@implementation RKSimplePostProcessor

@synthesize outputValue = _outputValue;
@synthesize outputError = _outputError;

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
