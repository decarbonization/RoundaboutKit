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
///Post-processors may specify an input type through their `+[self inputValueType]`
///method. Runtime type-checking will be performed by the clients of RKPostProcessor
///contained in RoundaboutKit.
///
///Post-processors perform their work using their primitive method `+[self processValue:
///error:withContext:]`. Post-processors are assumed to be stateless. Subclasses should
///provide singletons to reduce memory usage.
///
///The RKPostProcessor root class simply passes its input value and error into its output properties.
@interface RKPostProcessor : NSObject

#pragma mark - Types

///Returns the expected class for input values given to the post-processor.
///
///Return nil to indicate any type is acceptable.
- (Class)inputValueType;

#pragma mark - Processing

///Perform the post-processor's logic on a given input value,
///placing any processing errors into the `outError` pointer,
///and returning the processed value.
///
/// \param  value       A value of type `-[self inputValueType]`. May be nil.
/// \param  outError    A pointer that should be populated with an error if
///                     an issue arrises during post-processing.
/// \param  context     The object that is invoking the post-processor. When a
///                     post-processor is being used with RKPromise, this will
///                     be the RKPromise. May be nil.
///
/// \result A value. nil is considered a valid value.
///         To indicate an error, write to `outError`.
///
///This method is always invoked from a background thread. Post-processors
///are never shared between threads.
- (id)processValue:(id)value error:(NSError **)outError withContext:(id)context;

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
///implementation of RKPostProcessor. It is designed to provide source-level backwards
///compatibility with the old `RKURLRequestPromise` post- processor implementation.
@interface RKSimplePostProcessor : RKPostProcessor

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
