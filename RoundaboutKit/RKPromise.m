//
//  RKPromise.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 6/13/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import "RKPromise.h"

#import <libkern/OSAtomic.h>
#import <pthread.h>

#import "RKQueueManager.h"
#import "RKPossibility.h"
#import "RKPostProcessor.h"

///Returns a string representation for a given state.
static NSString *kRKPromiseStateGetString(kRKPromiseState state)
{
    switch (state) {
        case kRKPromiseStateReady:
            return @"kRKPromiseStateReady";
            
        case kRKPromiseStateAcceptedWithValue:
            return @"kRKPromiseStateAcceptedWithValue";
            
        case kRKPromiseStateRejectedWithError:
            return @"kRKPromiseStateRejectedWithError";
    }
}

///Locks a given pthread mutex and applies a block, wrapped in a @try...@finally
///statement so that the mutex is always unlocked, regardless of exceptions being
///thrown. Time trials indicated that this was still substantially faster than
///using @synchronized on an iPhone 5s and a Retina MacBook Pro 2012.
RK_INLINE void with_locked_state(pthread_mutex_t *mutex, dispatch_block_t block)
{
    if(!mutex || !block)
        return;
    
    @try {
        pthread_mutex_lock(mutex);
        
        block();
    } @finally {
        pthread_mutex_unlock(mutex);
    }
}

#pragma mark -

@interface RKPromise ()

#pragma mark - State

///Readwrite.
@property (readwrite) kRKPromiseState state;

///The contents of the promise, as described by `self.state`.
@property id contents;

///Whether or not the promise has been invoked.
@property BOOL hasInvoked;

#pragma mark - Blocks

///The block to invoke upon success.
@property (copy) RKPromiseAcceptedNotificationBlock thenBlock;

///The block to invoke upon failure.
@property (copy) RKPromiseRejectedNotificationBlock otherwiseBlock;

///The queue to invoke the blocks on.
@property NSOperationQueue *queue;

@end

#pragma mark -

@implementation RKPromise {
    ///The lock that regulates access to the promise's contents and state.
    pthread_mutex_t _stateGuard;
    
    ///Any post-processors associated with the promise. Lazily initialized.
    NSMutableArray *_postProcessors;
}

- (void)dealloc
{
    int mutexDestroyStatus = pthread_mutex_destroy(&_stateGuard);
    if(mutexDestroyStatus != noErr) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Could not destroy state guard for promise. %d", mutexDestroyStatus];
    }
}

- (instancetype)init
{
    if((self = [super init])) {
        self.promiseName = @"<anonymous>";
        
        _stateGuard = (pthread_mutex_t)PTHREAD_MUTEX_INITIALIZER;
        int mutexInitStatus = pthread_mutex_init(&_stateGuard, NULL);
        if(mutexInitStatus != noErr) {
            [NSException raise:NSInternalInconsistencyException
                        format:@"Could not create state guard for promise. %d", mutexInitStatus];
        }
    }
    
    return self;
}

#pragma mark - Convenience

+ (instancetype)acceptedPromiseWithValue:(id)value
{
    RKPromise *promise = [self new];
    [promise accept:value];
    return promise;
}

+ (instancetype)rejectedPromiseWithError:(NSError *)error
{
    RKPromise *promise = [self new];
    [promise reject:error];
    return promise;
}

#pragma mark - Plural Realization

+ (RKPromise *)when:(NSArray *)promises
{
    NSParameterAssert(promises);
    
    RKPromise *whenPromise = [RKPromise new];
    
    NSOperationQueue *realizationQueue = [NSOperationQueue new];
    realizationQueue.name = @"com.roundabout.rk.promise.when.callbackqueue";
    realizationQueue.maxConcurrentOperationCount = 1;
    [realizationQueue addOperationWithBlock:^{
        NSMutableArray *results = [promises mutableCopy];
        __block NSUInteger numberOfRealizedPromises = 0;
        for (NSUInteger index = 0, totalPromises = promises.count; index < totalPromises; index++) {
            RKPromise *promise = promises[index];
            
            [promise then:^(id result) {
                RKPossibility *possibility = [[RKPossibility alloc] initWithValue:result];
                [results replaceObjectAtIndex:index withObject:possibility];
                
                numberOfRealizedPromises++;
                if(numberOfRealizedPromises == totalPromises) {
                    [whenPromise accept:results];
                }
            } otherwise:^(NSError *error) {
                RKPossibility *possibility = [[RKPossibility alloc] initWithError:error];
                [results replaceObjectAtIndex:index withObject:possibility];
                
                numberOfRealizedPromises++;
                if(numberOfRealizedPromises == totalPromises) {
                    [whenPromise accept:results];
                }
            } onQueue:realizationQueue];
        }
    }];
    
    return whenPromise;
}

#pragma mark - Identity

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@:%p %@, state => %@, contents => %@>", NSStringFromClass(self.class), self, self.promiseName, kRKPromiseStateGetString(self.state), self.contents];
}

#pragma mark - Propagating Values

- (id)postProcessAcceptedValue:(id)value error:(NSError **)outError
{
    NSError *error = nil;
    for (RKPostProcessor *postProcessor in _postProcessors) {
        if([postProcessor inputValueType] && value && ![value isKindOfClass:[postProcessor inputValueType]])
            [NSException raise:NSInvalidArgumentException format:@"Post-processor %@ given value of type %@, expected %@.", postProcessor, [value class], [postProcessor inputValueType]];
        
        value = [postProcessor processValue:value error:&error withContext:self];
        if(error)
            break;
    }
    
    if(outError) *outError = error;
    
    return value;
}

#pragma mark -

- (void)accept:(id)value
{
    if(self.contents != nil)
        @throw [NSException exceptionWithName:NSInternalInconsistencyException 
                                       reason:@"Cannot accept a promise more than once"
                                     userInfo:nil];
    
    with_locked_state(&_stateGuard, ^{
        NSError *error = nil;
        id processedValue = [self postProcessAcceptedValue:value error:&error];
        if(error) {
            self.contents = error;
            self.state = kRKPromiseStateRejectedWithError;
        } else {
            self.contents = processedValue;
            self.state = kRKPromiseStateAcceptedWithValue;
            
        }
        
        [self invoke];
    });
}

- (void)reject:(NSError *)error
{
    if(self.contents != nil)
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Cannot reject a promise more than once"
                                     userInfo:nil];
    
    with_locked_state(&_stateGuard, ^{
        self.contents = error;
        self.state = kRKPromiseStateRejectedWithError;
        
        [self invoke];
    });
}

#pragma mark - Processors

- (void)addPostProcessors:(NSArray *)processors
{
    NSParameterAssert(processors);
    
    if(self.contents != nil)
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Cannot add a post-processor to an already-realized promise."
                                     userInfo:nil];
    
    with_locked_state(&_stateGuard, ^{
        if(!_postProcessors)
            _postProcessors = [NSMutableArray new];
        
        [_postProcessors addObjectsFromArray:processors];
    });
}

- (void)addPostProcessor:(RKPostProcessor *)postProcessor
{
    NSParameterAssert(postProcessor);
    
    [self addPostProcessors:@[ postProcessor ]];
}

- (void)setPostProcessors:(NSArray *)postProcessors
{
    if(self.contents != nil)
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Cannot set post-processors on an already-realized promise."
                                     userInfo:nil];
    
    with_locked_state(&_stateGuard, ^{
        if(!_postProcessors)
            _postProcessors = [NSMutableArray new];
        
        [_postProcessors setArray:postProcessors];
    });
}

- (NSArray *)postProcessors
{
    return [_postProcessors copy] ?: @[];
}

#pragma mark - Realizing

- (void)doneInvoking
{
    self.thenBlock = nil;
    self.otherwiseBlock = nil;
    self.queue = nil;
}

- (void)invoke
{
    if(self.thenBlock && self.otherwiseBlock && self.queue) {
        self.hasInvoked = YES;
        
        switch (self.state) {
            case kRKPromiseStateAcceptedWithValue: {
                [self.queue addOperationWithBlock:^{
                    self.thenBlock(self.contents);
                    [self doneInvoking];
                }];
                
                break;
            }
                
            case kRKPromiseStateRejectedWithError: {
                [self.queue addOperationWithBlock:^{
                    self.otherwiseBlock(self.contents);
                    [self doneInvoking];
                }];
                
                break;
            }
                
            case kRKPromiseStateReady: {
                break;
            }
        }
    }
}

#pragma mark -

- (void)fire
{
    //Do nothing.
}

#pragma mark -

- (void)then:(RKPromiseAcceptedNotificationBlock)then otherwise:(RKPromiseRejectedNotificationBlock)otherwise
{
    [self then:then otherwise:otherwise onQueue:[NSOperationQueue currentQueue]];
}

- (void)then:(RKPromiseAcceptedNotificationBlock)then otherwise:(RKPromiseRejectedNotificationBlock)otherwise onQueue:(NSOperationQueue *)queue
{
    NSParameterAssert(then);
    NSParameterAssert(otherwise);
    NSParameterAssert(queue);
    
    if(self.hasInvoked) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Cannot realize a promise more than once"
                                     userInfo:nil];
    }
    
    with_locked_state(&_stateGuard, ^{
        self.thenBlock = then;
        self.otherwiseBlock = otherwise;
        self.queue = queue;
        self.hasInvoked = YES;
        
        if(self.state != kRKPromiseStateReady) {
            [self invoke];
        } else {
            [self fire];
        }
    });
}

#pragma mark -

- (id)waitForRealization:(NSError **)outError
{
    __block id resultValue = nil;
    __block NSError *resultError = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self then:^(id value) {
        resultValue = value;
        
        dispatch_semaphore_signal(semaphore);
    } otherwise:^(NSError *error) {
        resultError = error;
        
        dispatch_semaphore_signal(semaphore);
    } onQueue:[RKQueueManager sharedQueueWithName:@"com.roundabout.rk.RKPromise.await-queue"]];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    if(outError) *outError = resultError;
    
    return resultValue;
}

@end
