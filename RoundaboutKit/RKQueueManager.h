//
//  RKQueueManager.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 6/13/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#ifndef RKQueueManager_h
#define RKQueueManager_h 1

#import <Foundation/Foundation.h>

///The RKQueueManager class manages a collection of named queues which tasks can be executed on.
@interface RKQueueManager : NSObject

///Returns the shared queue cache, creating it if it does not already exist.
+ (NSCache *)queueCache;

///Sets the queue associated with a given name.
///
/// \param  queue       The queue. Required.
/// \param  queueName   The name used to find the queue later. Required.
///
///This method should be used if a non-standard configuration queue is required.
+ (void)setSharedQueue:(NSOperationQueue *)queue withName:(NSString *)queueName;

///Returns a queue matching a given name.
///
/// \param  queueName   The name of the queue to find. Required.
///
/// \result A queue corresponding to the name given. If no existing queue
///         with the given name exists, one is created and associated with
///         the shared cache.
///
///This method may return different values if called concurrently
///from multiple threads. The returned queue may not be reconfigured.
+ (NSOperationQueue *)sharedQueueWithName:(NSString *)queueName;

///Returns a common catch-all queue suitable for use for short-lived background tasks.
///
///The returned queue is subject to the same rules as
///all other queues vended by the RKQueueManager class.
+ (NSOperationQueue *)commonWorkQueue;

@end

#pragma mark -

///Deprecated.
RK_EXTERN_OVERLOADABLE void RKDoAsync(dispatch_block_t actions) RK_DEPRECATED_SINCE_2_1;

#endif /* RKQueueManager_h */
