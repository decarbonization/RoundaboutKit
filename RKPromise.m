//
//  RKPromise.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 5/19/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#import "RKPromise.h"
#import <objc/runtime.h>

@implementation RKPromise

- (BOOL)isMultiPart
{
    return NO;
}

#pragma mark - Cancelling

- (IBAction)cancel:(id)sender
{
	self.cancelled = YES;
}

#pragma mark - Execution

- (void)executeWithSuccessBlock:(RKPromiseSuccessBlock)onSuccess
				   failureBlock:(RKPromiseFailureBlock)onFailure
				  callbackQueue:(NSOperationQueue *)callbackQueue
{
	//Do nothing
}

@end

#pragma mark - Singular Realization

RK_OVERLOADABLE void RKRealize(RKPromise *promise,
							   RKPromiseSuccessBlock success,
							   RKPromiseFailureBlock failure,
							   NSOperationQueue *callbackQueue)
{
	if(!promise)
		return;
	
	[promise executeWithSuccessBlock:success failureBlock:failure callbackQueue:callbackQueue];
}

RK_OVERLOADABLE void RKRealize(RKPromise *promise, 
							   RKPromiseSuccessBlock success,
							   RKPromiseFailureBlock failure)
{
	RKRealize(promise, success, failure, [NSOperationQueue currentQueue]);
}

#pragma mark - Plural Realization

RK_OVERLOADABLE void RKRealizePromises(NSArray *promises,
									   void(^callback)(NSArray *possibilities))
{
	RKRealizePromises(promises, callback, [NSOperationQueue currentQueue]);
}
RK_OVERLOADABLE void RKRealizePromises(NSArray *promises,
									   void(^callback)(NSArray *possibilities),
									   NSOperationQueue *callbackQueue)
{
	NSCParameterAssert(promises);
	NSCParameterAssert(callback);
	NSCParameterAssert(callbackQueue);
	
	NSUInteger numberOfPromises = [promises count];
	NSMutableArray *completedPromises = [NSMutableArray array];
	for (RKPromise *promise in [promises copy]) {
        //We do not support multi-part promises. Period.
        if(promise.isMultiPart) {
            [NSException raise:NSInternalInconsistencyException
                        format:@"RKRealizePromises cannot be used with a multi-part promise."];
        }
        
		RKRealize(promise, ^(id result) {
			RKPossibility *possibility = [[RKPossibility alloc] initWithValue:result];
			@synchronized(completedPromises) {
				[completedPromises addObject:possibility];
				if([completedPromises count] == numberOfPromises) {
					[callbackQueue addOperationWithBlock:^{
						if(callback) callback(completedPromises);
					}];
				}
			}
		}, ^(NSError *error) {
			RKPossibility *possibility = [[RKPossibility alloc] initWithError:error];
			@synchronized(completedPromises) {
				[completedPromises addObject:possibility];
				if([completedPromises count] == numberOfPromises) {
					[callbackQueue addOperationWithBlock:^{
						if(callback) callback(completedPromises);
					}];
				}
			}
		}, callbackQueue);
	}
}

#pragma mark -

@implementation RKBlockPromise

#pragma mark Shared Queue

+ (NSOperationQueue *)defaultBlockPromiseQueue
{
	static NSOperationQueue *sharedRealizationQueue = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedRealizationQueue = [NSOperationQueue new];
        [sharedRealizationQueue setName:@"com.roundabout.RoundaboutKit.RKBlockPromise.sharedRealizationQueue"];
	});
	
	return sharedRealizationQueue;
}

#pragma mark - Initialization

- (id)initWithWorker:(RKBlockPromiseWorker)worker operationQueue:(NSOperationQueue *)operationQueue
{
	NSParameterAssert(worker);
    NSParameterAssert(operationQueue);
	
	if((self = [super init])) {
		mWorker = [worker copy];
        self.operationQueue = operationQueue;
	}
	
	return self;
}

- (id)initWithWorker:(RKBlockPromiseWorker)worker
{
    return [self initWithWorker:worker operationQueue:[[self class] defaultBlockPromiseQueue]];
}

#pragma mark - Blocks

@synthesize worker = mWorker;

#pragma mark - Execution

- (void)executeWithSuccessBlock:(RKPromiseSuccessBlock)onSuccess
				   failureBlock:(RKPromiseFailureBlock)onFailure
				  callbackQueue:(NSOperationQueue *)callbackQueue
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
	
    [self.operationQueue addOperationWithBlock:^{
        mWorker(self, ^(id result) {
            [callbackQueue addOperationWithBlock:^{
                self.isFinished = YES;
                onSuccess(result);
            }];
		}, ^(NSError *error) {
			[callbackQueue addOperationWithBlock:^{
                self.isFinished = YES;
                onFailure(error);
            }];
		});
    }];
	
	mHasBeenRealized = YES;
}

@end
