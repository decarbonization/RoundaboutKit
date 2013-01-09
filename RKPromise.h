//
//  RKPromise.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 5/19/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#ifndef RKPromise_h
#define RKPromise_h 1

#import <Foundation/Foundation.h>
#import "RKPossibility.h"

///A block to invoke upon successful realization of a promise.
typedef void(^RKPromiseSuccessBlock)(id data);

///A block to invoke upon non-successful realization of a promise.
typedef void(^RKPromiseFailureBlock)(NSError *error);

#pragma mark -

///The abstract base class upon which all other promise types derive.
@interface RKPromise : NSObject

///Returns whether or not the promise is multi-part.
- (BOOL)isMultiPart;

#pragma mark - Canceling

///Whether or not the abstract promise is cancelled.
///
///Subclasses of RKPromise should check this property periodically.
@property BOOL cancelled;

///Cancel the receiver.
- (IBAction)cancel:(id)sender;

#pragma mark - Grouping

///The name of the group that the promise belongs to.
@property (copy) NSString *groupName;

#pragma mark - Execution

///Execute the work of the promise.
///
///	\param	onSuccess		The block to invoke upon successful execution. Required.
///	\param	onFailure		The block to invoke upon non-successful execution. Required.
///	\param	callbackQueue	The queue to invoke the blocks on. Required.
///
///It is up to subclasses to implement a strategy for executing promises asynchronously.
///The default implementation of this method does nothing.
- (void)executeWithSuccessBlock:(RKPromiseSuccessBlock)onSuccess
				   failureBlock:(RKPromiseFailureBlock)onFailure
				  callbackQueue:(NSOperationQueue *)callbackQueue;

@end

#pragma mark - Multi-Part Promises

///The different parts of a multi-part promise.
typedef enum RKMultiPartPromisePart : NSUInteger {
    
    ///The first part of the promise.
    kRKMultiPartPromisePartFirst = 1,
    
    ///The second part of the promise.
    kRKMultiPartPromisePartSecond = 2,
    
} RKMultiPartPromisePart;

///A block to invoke upon successful completion of the first segment of a multi-part promise.
///
/// \param  data            The data given.
/// \param  willContinue    Whether or not the next part of the promise will be invoked.
///
/// \seealso(kRKMultiPartPromisePartFirst)
typedef void(^RKMultiPartPromiseFirstSuccessBlock)(id data, BOOL willContinue);

///A block to invoke upon successful completion of the second segment of a multi-part promise.
///
/// \param  data    The data given.
///
/// \seealso(kRKMultiPartPromisePartSecond)
typedef void(^RKMultiPartPromiseSecondSuccessBlock)(id data);

///A block to invoke upon successful completion of both segments of a multi-part promise.
///
/// \param  data        The data given.
/// \param  fromPart    The part of the promise that has been completed.
///
/// \seealso(RKMultiPartPromisePart)
typedef void(^RKMultiPartPromiseCombinedSuccessBlock)(id data, RKMultiPartPromisePart fromPart);

///A block to invoke upon non-successful realization of a multi-part promise.
///
/// \param  error       The error that occurred
/// \param  fromPart    The part of the realization process this error came from.
///
/// \seealso(RKMultiPartPromisePart)
typedef void(^RKMultiPartPromiseFailureBlock)(NSError *error, RKMultiPartPromisePart fromPart);

///The RKMultiPartPromise class is an abstract subclass of RKPromise that adds support for
///promises that complete in multiple parts.
@interface RKMultiPartPromise : RKPromise

#pragma mark - Execution

///Execute the work of the promise.
///
/// \param  onFirstSuccess  The block to invoke upon successful execution of the first part of the promise. Required.
/// \param  onSecondSuccess The block to invoke upon successful execution of the final part of the promise. Required.
/// \param  onFailure       The block t invoke upon non-successful execution of the promise. Required.
/// \param  callbackQueue   The queue to invoke the blocks on. Required.
///
///It is up to subclasses to implement a strategy for executing promises asynchronously.
///The default implementation of this method does nothing.
- (void)executeWithFirstSuccessBlock:(RKMultiPartPromiseFirstSuccessBlock)onFirstSuccess
                  secondSuccessBlock:(RKMultiPartPromiseSecondSuccessBlock)onSecondSuccess
                        failureBlock:(RKMultiPartPromiseFailureBlock)onFailure
                       callbackQueue:(NSOperationQueue *)callbackQueue;

@end

#pragma mark - Singular Realization

///Realize a promise.
///
///	\param	promise			The promise to realize. Optional.
///	\param	success			The block to invoke if the promise is successfully realized. Optional.
///	\param	failure			The block to invoke if the promise cannot be realized. Optional.
///	\param	callbackQueue	The queue to invoke the callback blocks on. This parameter may be ommitted.
///
///This function will asynchronously invoke the `promise`, and subsequently
///invoke either the `success`, or `failure` on the queue that invoked this
///function initially.
///
///If promise is nil, then this function does nothing.
RK_EXTERN_OVERLOADABLE void RKRealize(RKPromise *promise,
                                      RKPromiseSuccessBlock success,
                                      RKPromiseFailureBlock failure);
RK_EXTERN_OVERLOADABLE void RKRealize(RKPromise *promise,
                                      RKPromiseSuccessBlock success,
                                      RKPromiseFailureBlock failure,
                                      NSOperationQueue *callbackQueue);

#pragma mark -

///Realize a multi-part promise.
///
///Two forms of this function exist for convenience.
///
///Form 1:
/// \param  onFirstSuccess  The block to invoke upon successful execution of the first part of the promise. Required.
/// \param  onSecondSuccess The block to invoke upon successful execution of the final part of the promise. Required.
/// \param  onFailure       The block t invoke upon non-successful execution of the promise. Required.
/// \param  callbackQueue   The queue to invoke the blocks on. May be ommitted at call site. May not be nil otherwise.
///
///
///Form 2:
/// \param  onSuccess  The block to invoke (multiple times) upon successful execution of both parts of the promise. Required.
/// \param  onFailure       The block t invoke upon non-successful execution of the promise. Required.
///
///This function will asynchronously invoke the `promise`, and subsequently
///invoke either the first and success blocks, or the failure block on
///the queue that invoked this function initially.
///
///If promise is nil, then this function does nothing.
RK_EXTERN_OVERLOADABLE void RKRealizeMultiPart(RKMultiPartPromise *promise,
                                               RKMultiPartPromiseCombinedSuccessBlock onSuccess,
                                               RKMultiPartPromiseFailureBlock onFailure);
RK_EXTERN_OVERLOADABLE void RKRealizeMultiPart(RKMultiPartPromise *promise,
                                               RKMultiPartPromiseFirstSuccessBlock onFirstSuccess,
                                               RKMultiPartPromiseSecondSuccessBlock onSecondSuccess,
                                               RKMultiPartPromiseFailureBlock onFailure);
RK_EXTERN_OVERLOADABLE void RKRealizeMultiPart(RKMultiPartPromise *promise,
                                               RKMultiPartPromiseFirstSuccessBlock onFirstSuccess,
                                               RKMultiPartPromiseSecondSuccessBlock onSecondSuccess,
                                               RKMultiPartPromiseFailureBlock onFailure,
                                               NSOperationQueue *callbackQueue);

#pragma mark - Plural Realization (Deprecated)

///Realize an array of promises.
///
///	\param	promises		An array of non-multi-part promise objects to realize. Required.
///	\param	callback		A block accepting an array of RKPossibilities. Required.
///	\param	callbackQueue	The queue to invoke the callback on. This parameter may be ommitted.
///
///This form of RKRealizePromises is deprecated due to issues with incorporating
///multi-part promises with a serial realization system of this nature.
RK_EXTERN_OVERLOADABLE void RKRealizePromises(NSArray *promises,
                                              void(^callback)(NSArray *possibilities)) DEPRECATED_ATTRIBUTE;
RK_EXTERN_OVERLOADABLE void RKRealizePromises(NSArray *promises,
                                              void(^callback)(NSArray *possibilities),
                                              NSOperationQueue *callbackQueue) DEPRECATED_ATTRIBUTE;

#pragma mark -

@class RKBlockPromise;

///An RKBlockPromise worker block.
///
///	\param	me			The promise the block is represented by.
///	\param	onSuccess	A proxy block that will invoke the real `onSuccess` block on the callback queue.
///	\param	onSuccess	A proxy block that will invoke the real `onFailure` block on the callback queue.
///
///Executed on the common block promise dispatch queue.
typedef void(^RKBlockPromiseWorker)(RKBlockPromise *me, RKPromiseSuccessBlock onSuccess, RKPromiseFailureBlock onFailure);

///A concrete subclass of RKPromise that provides a
///simple block based implementation of the promise interface.
///
///RKBlockPromise's which have been `cancelled` will not execute
///their workers.
@interface RKBlockPromise : RKPromise
{
	RKBlockPromiseWorker mWorker;
	BOOL mHasBeenRealized;
}

///Returns the default block promise operation queue, creating it if it does not exist.
///
///This is a parallel queue. The properties of this queue should not be modified.
+ (NSOperationQueue *)defaultBlockPromiseQueue;

///Initialize a block promise.
///
///All parameters required.
- (id)initWithWorker:(RKBlockPromiseWorker)worker;

#pragma mark - Properties

///The worker block of the promise.
@property (readonly) RKBlockPromiseWorker worker;

///The queue to execute this block promise on.
@property NSOperationQueue *operationQueue;

@end

#endif /* RKPromise_h */
