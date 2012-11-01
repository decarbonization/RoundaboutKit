//
//  RKPromise.h
//  Pinna
//
//  Created by Kevin MacWhinnie on 5/19/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#ifndef RKPromise_h
#define RKPromise_h 1

#import <Foundation/Foundation.h>

///A block to invoke upon successful realization of a promise.
typedef void(^RKPromiseSuccessBlock)(id result);

///A block to invoke upon non-successful realization of a promise.
typedef void(^RKPromiseFailureBlock)(NSError *error);

#pragma mark -

///The abstract base class upon which all other promise types derive.
@interface RKPromise : NSObject
{
}

#pragma mark Canceling

///Whether or not the abstract promise is cancelled.
///
///Subclasses of RKPromise should check this property periodically.
@property BOOL cancelled;

///Cancel the receiver.
- (IBAction)cancel:(id)sender;

#pragma mark -
#pragma mark Grouping

///The name of the group that the promise belongs to.
@property (copy) NSString *groupName;

#pragma mark -
#pragma mark Execution

///Execute the work of the promise.
///
///	\param	onSuccess		The block to invoke upon successful execution. Required.
///	\param	onFailure		The block to invoke upon successful execution. Required.
///	\param	callbackQueue	The queue to invoke the blocks on. Required.
///
///It is up to subclasses to implement a strategy for executing promises asynchronously.
///The default implementation of this method does nothing.
- (void)executeWithSuccessBlock:(RKPromiseSuccessBlock)onSuccess
				   failureBlock:(RKPromiseFailureBlock)onFailure
				  callbackQueue:(dispatch_queue_t)callbackQueue;

@end

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

///Initialize a block promise.
///
///All parameters required.
- (id)initWithWorker:(RKBlockPromiseWorker)worker;

#pragma mark -
#pragma mark Properties

///The worker block of the promise.
@property (readonly) RKBlockPromiseWorker worker;

@end

#pragma mark -

///Create an RKBlockPromise with a specified block.
///
///	\param	implementation	The implementation of the promise. Required.
RK_EXTERN RKBlockPromise *RKPromiseCreate(RKBlockPromiseWorker worker);

#pragma mark -
#pragma mark Singular Realization

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
RK_OVERLOADABLE RK_EXTERN void RKRealize(RKPromise *promise, 
										 RKPromiseSuccessBlock success,
										 RKPromiseFailureBlock failure);
RK_OVERLOADABLE RK_EXTERN void RKRealize(RKPromise *promise, 
										 RKPromiseSuccessBlock success,
										 RKPromiseFailureBlock failure,
										 dispatch_queue_t callbackQueue);
#pragma mark -
#pragma mark Plural Realization

///The RKPossibility class represents the two possible outcomes of a given promise.
@interface RKPossibility : NSObject
{
	id mValue;
	NSError *mError;
}

///Initialize the receiver with a specified value.
- (id)initWithValue:(id)value;

///Initialize the receiver with a specified error.
- (id)initWithError:(NSError *)error;

#pragma mark -
#pragma mark Properties

///The possible value.
@property (readonly) id value;

///The possible error.
@property (readonly) NSError *error;

@end

#pragma mark -

///Realize an array of promises.
///
///	\param	promises		An array of promise objects to realize. Required.
///	\param	callback		A block accepting an array of RKPossibilities. Required.
///	\param	callbackQueue	The queue to invoke the callback on. This parameter may be ommitted.
///
RK_OVERLOADABLE RK_EXTERN void RKRealizePromises(NSArray *promises,
												 void(^callback)(NSArray *possibilities));
RK_OVERLOADABLE RK_EXTERN void RKRealizePromises(NSArray *promises,
												 void(^callback)(NSArray *possibilities),
												 dispatch_queue_t callbackQueue);

#endif /* RKPromise_h */
