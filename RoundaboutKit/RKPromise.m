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
static NSString *RKPromiseStateGetString(RKPromiseState state)
{
    switch (state) {
        case RKPromiseStateNotRealized:
            return @"RKPromiseStateNotRealized";
            
        case RKPromiseStateValue:
            return @"RKPromiseStateValue";
            
        case RKPromiseStateError:
            return @"RKPromiseStateError";
    }
}

#pragma mark -

@interface RKPromise ()

#pragma mark - State

///Readwrite.
@property (readwrite) RKPromiseState state;

///The contents of the promise, as described by `self.state`.
@property id contents;

///Whether or not the promise has been invoked.
@property BOOL hasInvoked;

#pragma mark - Blocks

///The block to invoke upon success.
@property (copy) RKPromiseThenBlock thenBlock;

///The block to invoke upon failure.
@property (copy) RKPromiseErrorBlock otherwiseBlock;

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
    
    NSOperationQueue *realizationQueue = [RKQueueManager commonQueue];
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
    return [NSString stringWithFormat:@"<%@:%p %@, state => %@, contents => %@>", NSStringFromClass(self.class), self, self.promiseName, RKPromiseStateGetString(self.state), self.contents];
}

#pragma mark - Propagating Values

///Takes an input value and error, passes them through any post-processors
///associated with the promise, and sets the receivers `self.contents` and
///`self.state` properties.
///
/// \param  value   The value that was accepted, if any.
/// \param  error   The error occurred, if any. This value being non-nil
///                 indicates to post-processors that an error occurred.
///
///The `self.contents` and `self.state` properties will be set after this
///method finishes executing. This method should _only_ be called when the
///`_stateGuard` is locked.
- (void)processValue:(id)value error:(NSError *)error
{
    for (id <RKPostProcessor> postProcessor in _postProcessors) {
        if([postProcessor inputValueType] && ![value isKindOfClass:[postProcessor inputValueType]])
            [NSException raise:NSInvalidArgumentException format:@"Post-processor %@ given value of type %@, expected %@.", postProcessor, [value class], [postProcessor inputValueType]];
        
        [postProcessor processInputValue:value inputError:error context:self];
        
        value = postProcessor.outputValue;
        error = postProcessor.outputError;
    }
    
    if(error) {
        self.contents = error;
        self.state = RKPromiseStateError;
    } else {
        self.contents = value;
        self.state = RKPromiseStateValue;
    }
}

#pragma mark -

- (void)accept:(id)value
{
    if(self.contents != nil)
        @throw [NSException exceptionWithName:NSInternalInconsistencyException 
                                       reason:@"Cannot accept a promise more than once"
                                     userInfo:nil];
    
    pthread_mutex_lock(&_stateGuard);
    {
        [self processValue:value error:nil];
        [self invoke];
    }
    pthread_mutex_unlock(&_stateGuard);
}

- (void)reject:(NSError *)error
{
    if(self.contents != nil)
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Cannot reject a promise more than once"
                                     userInfo:nil];
    
    pthread_mutex_lock(&_stateGuard);
    {
        [self processValue:nil error:error];
        [self invoke];
    }
    pthread_mutex_unlock(&_stateGuard);
}

#pragma mark - Processors

- (void)addPostProcessors:(NSArray *)processors
{
    NSParameterAssert(processors);
    
    if(self.contents != nil)
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Cannot add a post-processor to an already-realized promise."
                                     userInfo:nil];
    
    pthread_mutex_lock(&_stateGuard);
    {
        if(!_postProcessors)
            _postProcessors = [NSMutableArray new];
        
        [_postProcessors addObjectsFromArray:processors];
    }
    pthread_mutex_unlock(&_stateGuard);
}

- (void)removeAllPostProcessors
{
    pthread_mutex_lock(&_stateGuard);
    {
        [_postProcessors removeAllObjects];
    }
    pthread_mutex_unlock(&_stateGuard);
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
            case RKPromiseStateValue: {
                [self.queue addOperationWithBlock:^{
                    self.thenBlock(self.contents);
                    [self doneInvoking];
                }];
                
                break;
            }
                
            case RKPromiseStateError: {
                [self.queue addOperationWithBlock:^{
                    self.otherwiseBlock(self.contents);
                    [self doneInvoking];
                }];
                
                break;
            }
                
            case RKPromiseStateNotRealized: {
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

- (void)then:(RKPromiseThenBlock)then otherwise:(RKPromiseErrorBlock)otherwise
{
    [self then:then otherwise:otherwise onQueue:[NSOperationQueue currentQueue]];
}

- (void)then:(RKPromiseThenBlock)then otherwise:(RKPromiseErrorBlock)otherwise onQueue:(NSOperationQueue *)queue
{
    NSParameterAssert(then);
    NSParameterAssert(otherwise);
    NSParameterAssert(queue);
    
    if(self.hasInvoked) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Cannot realize a promise more than once"
                                     userInfo:nil];
    }
    
    pthread_mutex_lock(&_stateGuard);
    {
        self.thenBlock = then;
        self.otherwiseBlock = otherwise;
        self.queue = queue;
        
        if(self.state != RKPromiseStateNotRealized) {
            [self invoke];
        } else {
            [self fire];
        }
    }
    pthread_mutex_unlock(&_stateGuard);
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
    } onQueue:[RKQueueManager queueNamed:@"com.roundabout.rk.RKPromise.await-queue"]];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    if(outError) *outError = resultError;
    
    return resultValue;
}

@end
