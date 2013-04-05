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
	
    NSOperationQueue *realizationQueue = [RKBlockPromise defaultBlockPromiseQueue];
    [realizationQueue addOperationWithBlock:^{
        NSMutableArray *results = [promises mutableCopy];
        __block NSUInteger numberOfRealizedPromises = 0;
        for (NSUInteger index = 0, count = promises.count; index < count; index++) {
            RKPromise *promise = promises[index];
            
            //We do not support multi-part promises. Period.
            if(promise.isMultiPart) {
                NSError *error = [NSError errorWithDomain:@"RKPromiseErrorDomain"
                                                     code:'+prt'
                                                 userInfo:@{NSLocalizedDescriptionKey: @"RKRealizePromises cannot be used with a multi-part promise."}];
                [results replaceObjectAtIndex:index withObject:[[RKPossibility alloc] initWithError:error]];
                
                continue;
            }
            
            RKRealize(promise, ^(id result) {
                RKPossibility *possibility = [[RKPossibility alloc] initWithValue:result];
                [results replaceObjectAtIndex:index withObject:possibility];
                
                numberOfRealizedPromises++;
                if(numberOfRealizedPromises == count) {
                    [callbackQueue addOperationWithBlock:^{
                        if(callback) callback(results);
                    }];
                }
            }, ^(NSError *error) {
                RKPossibility *possibility = [[RKPossibility alloc] initWithError:error];
                [results replaceObjectAtIndex:index withObject:possibility];
                
                numberOfRealizedPromises++;
                if(numberOfRealizedPromises == count) {
                    [callbackQueue addOperationWithBlock:^{
                        if(callback) callback(results);
                    }];
                }
            }, realizationQueue);
        }
    }];
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

#pragma mark -

RK_OVERLOADABLE void RKDoAsync(dispatch_block_t actions)
{
    if(!actions)
        return;
    
    [[RKBlockPromise defaultBlockPromiseQueue] addOperationWithBlock:actions];
}

@end
