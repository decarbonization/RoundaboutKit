//
//  RKAwait.c
//  LiveNationApp
//
//  Created by Kevin MacWhinnie on 3/8/13.
//  Copyright (c) 2013 Live Nation Labs. All rights reserved.
//

#import "RKAwait.h"

static NSOperationQueue *RKAwaitGetSharedQueue()
{
    static NSOperationQueue *sharedQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedQueue = [NSOperationQueue new];
        sharedQueue.name = @"com.roundabout.rkawait.sharedQueue";
    });
    
    return sharedQueue;
}

RK_OVERLOADABLE id RKAwait(RKPromise *promise, NSError **outError)
{
    if(!promise)
        return nil;
    
    __block id resultValue = nil;
    __block NSError *resultError = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    RKRealize(promise, ^(id value) {
        resultValue = value;
        
        dispatch_semaphore_signal(semaphore);
    }, ^(NSError *error) {
        resultError = error;
        
        dispatch_semaphore_signal(semaphore);
    }, RKAwaitGetSharedQueue());
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    if(outError) *outError = resultError;
    
    return resultValue;
}

RK_OVERLOADABLE id RKAwait(RKPromise *promise)
{
    NSError *error = nil;
    id value = RKAwait(promise, &error);
    if(!value && error) {
        @throw [NSException exceptionWithName:[error domain]
                                       reason:[error localizedDescription]
                                     userInfo:[error userInfo]];
    }
    
    return value;
}
