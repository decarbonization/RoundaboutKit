//
//  RKMockPromise.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import "RKMockPromise.h"

///The amount of time that should elapse between success callbacks.
#define SUCCESS_CALLBACK_SLEEP_TIME 0.1

@interface RKMockPromise ()

///The intended result of the mock promise.
@property RKPossibility *result;

///The amount of time that should elapse before a mock promise yields a value/error.
@property NSTimeInterval duration;

///Whether or not the mock can be cancelled.
@property (readwrite) BOOL canCancel;

///The number of successes.
@property NSUInteger numberOfSuccesses;

@end

@implementation RKMockPromise

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithResult:(RKPossibility *)result
            duration:(NSTimeInterval)duration
           canCancel:(BOOL)canCancel
   numberOfSuccesses:(NSUInteger)numberOfSuccesses
{
    NSParameterAssert(result);
    NSAssert((result.state != kRKPossibilityStateEmpty), @"Cannot pass an empty possibility to RKMockPromise.");
    NSAssert((numberOfSuccesses > 0), @"Cannot pass in 0 successes.");
    
    if((self = [super init])) {
        self.result = result;
        self.duration = duration;
        self.canCancel = canCancel;
        self.numberOfSuccesses = numberOfSuccesses;
    }
    
    return self;
}

#pragma mark - Properties

@synthesize canCancel = _canCancel;

- (BOOL)isMultiPart
{
    return (self.numberOfSuccesses > 1);
}

#pragma mark - Execution

- (void)executeWithSuccessBlock:(RKPromiseSuccessBlock)onSuccess
				   failureBlock:(RKPromiseFailureBlock)onFailure
				  callbackQueue:(NSOperationQueue *)callbackQueue
{
    NSParameterAssert(onSuccess);
    NSParameterAssert(onFailure);
    NSParameterAssert(callbackQueue);
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.duration * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if(self.cancelled)
            return;
        
        RKMatchPossibility(self.result, ^(id value) {
            if(self.isMultiPart) {
                for (NSUInteger index = 0; index < self.numberOfSuccesses; index++) {
                    if(self.cancelled)
                        return;
                    
                    [callbackQueue addOperationWithBlock:^{
                        onSuccess(value);
                    }];
                    
                    usleep((useconds_t)(SUCCESS_CALLBACK_SLEEP_TIME * 1000000.0));
                }
            } else {
                [callbackQueue addOperationWithBlock:^{
                    onSuccess(value);
                }];
            }
        }, kRKPossibilityDefaultEmptyMatcher, ^(NSError *error) {
            [callbackQueue addOperationWithBlock:^{
                onFailure(error);
            }];
        });
    });
}

@end
