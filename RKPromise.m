//
//  RKPromise.m
//  Pinna
//
//  Created by Kevin MacWhinnie on 5/19/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RKPromise.h"
#import <objc/runtime.h>

@implementation RKPromise

#pragma mark Cancelling

- (IBAction)cancel:(id)sender
{
	self.cancelled = YES;
}

#pragma mark -
#pragma mark Execution

- (void)executeWithSuccessBlock:(RKPromiseSuccessBlock)onSuccess
				   failureBlock:(RKPromiseFailureBlock)onFailure
				  callbackQueue:(dispatch_queue_t)callbackQueue
{
	//Do nothing
}

@end

#pragma mark -

@implementation RKBlockPromise

#pragma mark Shared Queue

+ (dispatch_queue_t)sharedRealizationQueue
{
	static dispatch_queue_t realizationQueue;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		realizationQueue = dispatch_queue_create("com.roundabout.RKPromise.realizationQueue", DISPATCH_QUEUE_CONCURRENT);
	});
	
	return realizationQueue;
}

#pragma mark -
#pragma mark Initialization

- (id)initWithWorker:(RKBlockPromiseWorker)worker
{
	NSParameterAssert(worker);
	
	if((self = [super init]))
	{
		mWorker = [worker copy];
	}
	
	return self;
}

#pragma mark -
#pragma mark Blocks

@synthesize worker = mWorker;

#pragma mark -
#pragma mark Execution

- (void)executeWithSuccessBlock:(RKPromiseSuccessBlock)onSuccess
				   failureBlock:(RKPromiseFailureBlock)onFailure
				  callbackQueue:(dispatch_queue_t)callbackQueue
{
	NSParameterAssert(onSuccess);
	NSParameterAssert(onFailure);
	NSParameterAssert(callbackQueue);
	
	NSAssert(!mHasBeenRealized, @"Attempting to realize an already-realized promise.");
	
	if(self.cancelled)
	{
		mHasBeenRealized = YES;
		return;
	}
	
	onSuccess = [onSuccess copy];
	onFailure = [onFailure copy];
	
	dispatch_async([RKBlockPromise sharedRealizationQueue], ^{
		mWorker(self, ^(id result) {
			dispatch_async(callbackQueue, ^{ onSuccess(result); });
		}, ^(NSError *error) {
			dispatch_async(callbackQueue, ^{ onFailure(error); });
		});
	});
	
	mHasBeenRealized = YES;
}

@end

#pragma mark -
#pragma mark Public

RKBlockPromise *RKPromiseCreate(RKBlockPromiseWorker worker)
{
	return [[RKBlockPromise alloc] initWithWorker:worker];
}

#pragma mark -
#pragma mark Singular Realization

RK_OVERLOADABLE void RKRealize(RKPromise *promise, 
							   RKPromiseSuccessBlock success,
							   RKPromiseFailureBlock failure,
							   dispatch_queue_t callbackQueue)
{
	if(!promise)
		return;
	
	[promise executeWithSuccessBlock:success failureBlock:failure callbackQueue:callbackQueue];
}

RK_OVERLOADABLE void RKRealize(RKPromise *promise, 
							   RKPromiseSuccessBlock success,
							   RKPromiseFailureBlock failure)
{
	RKRealize(promise, success, failure, dispatch_get_current_queue());
}

#pragma mark -
#pragma mark Plural Realization

@implementation RKPossibility

- (id)initWithValue:(id)value
{
	if((self = [super init]))
	{
		mValue = value;
	}
	
	return self;
}

- (id)initWithError:(NSError *)error
{
	if((self = [super init]))
	{
		mError = error;
	}
	
	return self;
}

#pragma mark -
#pragma mark Properties

@synthesize value = mValue;
@synthesize error = mError;

@end

#pragma mark -

RK_OVERLOADABLE void RKRealizePromises(NSArray *promises,
									   void(^callback)(NSArray *possibilities))
{
	RKRealizePromises(promises, callback, dispatch_get_current_queue());
}
RK_OVERLOADABLE void RKRealizePromises(NSArray *promises,
									   void(^callback)(NSArray *possibilities),
									   dispatch_queue_t callbackQueue)
{
	NSCParameterAssert(promises);
	NSCParameterAssert(callback);
	NSCParameterAssert(callbackQueue);
	
	NSUInteger numberOfPromises = [promises count];
	NSMutableArray *completedPromises = [NSMutableArray array];
	for (RKPromise *promise in [promises copy])
	{
		RKRealize(promise, ^(id result) {
			RKPossibility *possibility = [[RKPossibility alloc] initWithValue:result];
			@synchronized(completedPromises)
			{
				[completedPromises addObject:possibility];
				if([completedPromises count] == numberOfPromises)
				{
					dispatch_async(callbackQueue, ^{
						if(callback) callback(completedPromises);
					});
				}
			}
		}, ^(NSError *error) {
			RKPossibility *possibility = [[RKPossibility alloc] initWithError:error];
			@synchronized(completedPromises)
			{
				[completedPromises addObject:possibility];
				if([completedPromises count] == numberOfPromises)
				{
					dispatch_async(callbackQueue, ^{
						if(callback) callback(completedPromises);
					});
				}
			}
		}, callbackQueue);
	}
}
