//
//  RKQueueManager.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 6/13/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import "RKQueueManager.h"

@implementation RKQueueManager

+ (NSCache *)queueCache
{
    static NSCache *queueCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queueCache = [NSCache new];
        queueCache.name = @"com.roundabout.rk.queueManager.queueCache";
    });
    
    return queueCache;
}

+ (void)setSharedQueue:(NSOperationQueue *)queue withName:(NSString *)queueName
{
    NSParameterAssert(queue);
    NSParameterAssert(queueName);
    
    NSCache *queueCache = [self queueCache];
    [queueCache setObject:queue forKey:queueName];
}

+ (NSOperationQueue *)sharedQueueWithName:(NSString *)queueName
{
    NSParameterAssert(queueName);
    
    NSCache *queueCache = [self queueCache];
    
    NSOperationQueue *queue = [queueCache objectForKey:queueName];
    if(!queue) {
        queue = [NSOperationQueue new];
        queue.name = queueName;
        
        [queueCache setObject:queue forKey:queueName];
    }
    
    return queue;
}

+ (NSOperationQueue *)commonWorkQueue
{
    return [self sharedQueueWithName:@"com.roundabout.rk.queueManager.commonWorkQueue"];
}

@end

#pragma mark -

RK_OVERLOADABLE void RKDoAsync(dispatch_block_t actions)
{
    if(!actions)
        return;
    
    [[RKQueueManager commonWorkQueue] addOperationWithBlock:actions];
}
