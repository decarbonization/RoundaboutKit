//
//  RKPromise.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 6/13/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RKPostProcessor;

///The different states a promise object can be in.
typedef NS_ENUM(NSUInteger, kRKPromiseState) {
    ///The promise has not yet been accepted or rejected.
    kRKPromiseStateReady = 0,
    
    ///The promise has been accepted with a value.
    kRKPromiseStateAcceptedWithValue,
    
    ///The promise has been rejected with an error.
    kRKPromiseStateRejectedWithError,
};

///An observer block that will be invoked when a promise is accepted with a value.
///
/// \param  value   The value the promise was accepted with. `nil` is a valid value.
///
typedef void(^RKPromiseAcceptedNotificationBlock)(id);

///An observer block that will be invoked when a promise is rejected with an error.
///
/// \param  error   The error the promise was rejected with.
///
typedef void(^RKPromiseRejectedNotificationBlock)(NSError *error);

#pragma mark -

///The RKPromise class encapsulates the common promise pattern.
///
///Promises provide a layer of abstraction between an asynchronous task
///and a single observer wishing to know when the task has completed.
///Promises are intended to replace methods that initiate asynchronous work
///and take a callback block with a consistent, semi-composable pattern.
///
///Methods that initiate asynchronous tasks create and return a promise
///object. The caller of the method can then observe when the task
///completes either by waiting for it by blocking the current thread,
///or by providing success and failure callbacks to the returned promise.
///This process of waiting or attaching callbacks is called "Realization".
///The asynchronous task started by the method will notify the observer by
///either marking a promise as successful by having it "accept" a value,
///or by marking it as failed by having it "reject" an NSError. The value
///or error are then propagated back to the observer.
///
///RoundaboutKit offers a few additions on top of the basic promise pattern.
///These additions are laziness described by `<RKLazy>`, and cancelability
///as described by `<RKCancelable>`. A promise marked with `<RKLazy>` will
///cause asynchronous work to be performed when the promise is realized.
///A promise implementing the `<RKCancelable>` protocol has an additional
///property and method that make it possible for an observer to cancel the
///asynchronous task that created / is associated with the promise.
///
/// \seealso(<RKCancelable>, <RKLazy>, RKURLRequestPromise)
@interface RKPromise : NSObject

#pragma mark - Convenience

///Creates a new promise object, and calls `-[self accept:]` on it with a given value.
///
/// \param  The value to `accept` the promise with.
///
/// \result A new promise object that has already been realized.
+ (instancetype)acceptedPromiseWithValue:(id)value;

///Creates a new promise object, and calls `-[self reject:]` on it with a given error.
///
/// \param  The error to `reject` the promise with.
///
/// \result A new promise object that has already been realized.
+ (instancetype)rejectedPromiseWithError:(NSError *)error;

#pragma mark - Plural

///Realizes an array of promises, placing the results into the returned promise.
///
/// \param  promises    The promises to realize. Required.
///
/// \result A promise that will contain an array of RKPossibility
///         objects in the same order as the promises passed in.
///
+ (RKPromise *)when:(NSArray *)promises;

#pragma mark - State

///The name of the promise. Defaults to "<anonymous>". Useful for debugging.
@property (copy) NSString *promiseName;

///The cache identifier to use.
///
///Default value is nil.
@property (copy) NSString *cacheIdentifier;

///The state of the promise.
///
/// \seealso(kRKPromiseState)
@property (readonly) kRKPromiseState state;

#pragma mark - Propagating Values

///Mark the promise as successful and associate a value with it,
///invoking any `then` block currently associated with it.
///
/// \param  value   The success value to propagate. May be nil.
///
///This method or `-[self reject:]` may only be called once.
- (void)accept:(id)value;

///Mark the promise as failed and associate an error with it,
///invoking any `otherwise` block currently associated with it.
///
/// \param  error   The failure value to propagate. May be nil.
///
///This method or `-[self accept:]` may only be called once.
- (void)reject:(NSError *)error;

#pragma mark - Processors

///Adds an array of post-processors to execute when a promise is either
///accepted with a value, or rejected with an error. Post processors
///are executed in the order in which they are added to a promise.
///Refined values from post-processors are propagated downwards. That is
///to say, if you start with a post-processor that converts raw data into
///JSON objects, the next post-processor will receive those JSON objects.
///
/// \param  processors  An array of `RKPostProcessor` objects. Required.
///
///Post-processors may only be added to a promise before it is accepted/rejected.
///Attempting to do so after will result in an exception being raised. As such,
///promises that use post-processors should be fully initialized before tasks that
///will communicate through them are started.
///
///__Important:__ post processors are run on the thread that the promise is accepted/rejected from.
- (void)addPostProcessors:(NSArray *)processors;

///Removes all of the post-processors of the promise.
- (void)removeAllPostProcessors;

///Returns the post-processors of the promise.
@property (nonatomic, copy) NSArray *postProcessors;

#pragma mark - Realizing

///Provided as a simple way for subclasses of RKPromise to conform to the
///behavior described by the `<RKLazy>` protocol. The default implementation
///does nothing.
- (void)fire;

#pragma mark -

///Associate a acceptance block and a rejection block with the
///promise to be invoked when the promise is completed.
///
/// \param  then        The block to invoke if the promise is accepted. Required.
/// \param  otherwise   The block to invoke if the promise is rejected. Required.
///
///The blocks passed in will be invoked on the caller's operation queue.
///
/// \seealso(-[self then:otherwise:onQueue:])
- (void)then:(RKPromiseAcceptedNotificationBlock)then otherwise:(RKPromiseRejectedNotificationBlock)otherwise;

///Associate a acceptance block and a rejection block with the
///promise to be invoked when the promise is completed.
///
/// \param  then        The block to invoke upon success. Required.
/// \param  otherwise   The block to invoke upon failure. Required.
/// \param  queue       The queue to invoke the blocks on. Required.
///
/// \seealso(-[self then:otherwise:])
- (void)then:(RKPromiseAcceptedNotificationBlock)then otherwise:(RKPromiseRejectedNotificationBlock)otherwise onQueue:(NSOperationQueue *)queue;

#pragma mark -

///Blocks the calling thread until the receiver is either
///accepted with a value, or rejected with an error.
///
/// \param  outError    On return, pointer that contains an error object describing any issues.
///
/// \result If the promise was accepted, the value that was accepted;
///         if the promise was rejected, nil.
///
- (id)waitForRealization:(NSError **)outError;

@end

#pragma mark - Extensions

///The RKCancelable protocol describes an object that can be canceled.
///Intended to be used with `RKPromise` subclasses.
@protocol RKCancelable <NSObject>
@required

///Whether or not the object has been canceled.
@property (readonly) BOOL canceled;

///Cancels any activity in the receiver.
///
///It is safe to invoke this method from any thread,
///and for it be called any number of times.
- (IBAction)cancel:(id)sender;

@end

#pragma mark -

///The RKLazy protocol marks an object as deferring work necessary for
///it to have a value. Intended to be used with `RKPromise` subclasses.
///
///__Important:__ the RKLazy protocol simply marks a behavior, it does not
///directly prescribe a way for laziness to be implemented. The `RKPromise`
///class provides a hook for laziness in the form of the `-[RKPromise fire]`
///method. The `RKURLRequestPromise` class uses this method for its laziness.
@protocol RKLazy <NSObject>
@end

#if RoundaboutKit_EnableLegacyRealization

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
RK_INLINE RK_OVERLOADABLE void RKRealize(RKPromise *promise,
							   RKPromiseAcceptedNotificationBlock success,
							   RKPromiseRejectedNotificationBlock failure,
							   NSOperationQueue *callbackQueue)
{
	if(!promise)
		return;
	
	[promise then:success otherwise:failure onQueue:callbackQueue];
}
RK_INLINE RK_OVERLOADABLE void RKRealize(RKPromise *promise,
                                         RKPromiseAcceptedNotificationBlock success,
                                         RKPromiseRejectedNotificationBlock failure)
{
	RKRealize(promise, success, failure, [NSOperationQueue currentQueue]);
}


///Realizes a given promise object, blocking the caller's thread.
///
/// \param  promise     The promise to synchronously realize.
/// \param  outError    On return, pointer that contains an error object
///                     describing any issues. Parameter may be ommitted.
///
/// \result The result of realizing the promise.
///
///The two forms of RKAwait behave slightly differently. The form which includes
///an `outError` parameter will return nil when an error occurs. The form which
///does not include `outError` will raise an exception if an error occurs.
///In this form, if nil is returned it is the result of the promise.
RK_INLINE RK_OVERLOADABLE id RKAwait(RKPromise *promise, NSError **outError)
{
	return [promise waitForRealization:outError];
}
RK_INLINE RK_OVERLOADABLE id RKAwait(RKPromise *promise)
{
	NSError *error = nil;
    id value = RKAwait(promise, &error);
    if(!value) {
        @throw [NSException exceptionWithName:[error domain]
                                       reason:[error localizedDescription]
                                     userInfo:@{NSUnderlyingErrorKey: error}];
    }
    
    return value;
}

#endif /* RoundaboutKit_EnableLegacyRealization */
