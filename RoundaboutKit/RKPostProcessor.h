//
//  RKPromisePostProcessor.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/6/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#ifndef RKPostProcessor_h
#define RKPostProcessor_h 1

#import <Foundation/Foundation.h>

///The key used to embed the string representation of malformed data, if possible.
RK_EXTERN NSString *const RKPostProcessorBadValueStringRepresentationErrorUserInfoKey;

///The key used to embed the source URL of an error, if possible.
RK_EXTERN NSString *const RKPostProcessorSourceURLErrorUserInfoKey;

///An RKPostProcessor takes an input value and error, performs some work on it,
///and produces either an error or another object. They can be chained together
///to perform data conversions such as `NSData -> NSDictionary -> ModelObject`.
///
///Post processors specify their input and output types, and propagate their state
///through readwrite properties. Runtime type-checking can be performed by clients
///of the post-processor system.
@protocol RKPostProcessor <NSObject, NSCopying>

#pragma mark - Types

///Returns the expected class for input values given to the post-processor.
///
///Return nil to indicate `id` for any type is acceptable.
- (Class)inputValueType;

///Returns the class that output values will be an instance of.
///
///Return nil to indicate `id` for any type is possible.
- (Class)outputValueType;

#pragma mark - Output

///The end result of the post-processor.
@property (nonatomic) id outputValue;

///An error describing any issues that occurred during post-processing.
@property (nonatomic) NSError *outputError;

#pragma mark - Processing

///Perform the post-processor's logic on a given input value and error,
///setting the `self.outputValue` and `self.outputError` properties of
///the receiver.
///
/// \param  value   A result value of type `-[self inputValueType]`. May be nil.
/// \param  error   A result error. May be nil. This parameter should be used to
///                 determine if the previous work performed failed.
/// \param  context The object that is invoking the post-processor. When a post-
///                 processor is being used with RKPromise, this will be the RKPromise.
///
///This method is always invoked from a background thread. Post-processors
///are never shared between threads.
- (void)processInputValue:(id)value inputError:(NSError *)error context:(id)context;

@end

#pragma mark -

@class RKPossibility;

///The RKSimplePostProcessorBlock type describes implementations for the
///`RKSimplePostProcessor` class. It takes a possibility and context object,
///and returns a new possibilty,
///
/// \param  maybeData   The information the block is to operate on.
/// \param  context     The object that is invoking the post-processor.
///
/// \result A new possibility object describing the result of processing the input data.
///
/// \seealso(RKSimplePostProcessor, <RKPostProcessor>)
typedef RKPossibility *(^RKSimplePostProcessorBlock)(RKPossibility *maybeData, id context);

///The RKSimplePostProcessor class implements a simple, weakly typed, block-based
///implementation of the `<RKPostProcessor>` protocol. It is designed to provide
///source-level backwards compatibility with the old `RKURLRequestPromise` post-
///processor implementation.
@interface RKSimplePostProcessor : NSObject <RKPostProcessor>

///Initialize the receiver with an implementation block.
///
/// \param  block   The block that will serve as the implementation of the receiver. Required.
///
/// \result A fully initialized simple post processor object.
///
/// \seealso(RKSimplePostProcessorBlock)
- (instancetype)initWithBlock:(RKSimplePostProcessorBlock)block;

#pragma mark - Properties

///The implementation block.
@property (readonly, copy) RKSimplePostProcessorBlock block;

@end

///A simple post-processor block that takes an NSData object and yields JSON objects.
RK_EXTERN RKSimplePostProcessorBlock const kRKJSONPostProcessorBlock;

///A simple post-processor block that takes an NSData object and yields an NS/UIImage.
RK_EXTERN RKSimplePostProcessorBlock const kRKImagePostProcessorBlock;

///A simple post-processor block that takes an NSData object and yields a property list objects.
RK_EXTERN RKSimplePostProcessorBlock const kRKPropertyListPostProcessorBlock;

#endif /* RKPostProcessor_h */
