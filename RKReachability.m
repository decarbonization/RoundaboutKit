//
//  RKReachability.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/31/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#import "RKReachability.h"
#import <netinet/in.h>

NSString *RKReachabilityStatusGetDescription(RKReachabilityStatus status)
{
    NSMutableString *description = [NSMutableString string];
    if(RK_FLAG_IS_SET(status, kRKReachabilityStatusTransientConnection))
        [description appendString:@"kRKReachabilityStatusTransientConnection | "];
    if(RK_FLAG_IS_SET(status, kRKReachabilityStatusReachable))
        [description appendString:@"kRKReachabilityStatusReachable | "];
    if(RK_FLAG_IS_SET(status, kRKReachabilityStatusConnectionRequired))
        [description appendString:@"kRKReachabilityStatusConnectionRequired | "];
    if(RK_FLAG_IS_SET(status, kRKReachabilityStatusConnectionOnTraffic))
        [description appendString:@"kRKReachabilityStatusConnectionOnTraffic | "];
    if(RK_FLAG_IS_SET(status, kRKReachabilityStatusInterventionRequired))
        [description appendString:@"kRKReachabilityStatusInterventionRequired | "];
    if(RK_FLAG_IS_SET(status, kRKReachabilityStatusConnectionOnDemand))
        [description appendString:@"kRKReachabilityStatusConnectionOnDemand | "];
    if(RK_FLAG_IS_SET(status, kRKReachabilityStatusIsLocalAddress))
        [description appendString:@"kRKReachabilityStatusIsLocalAddress | "];
    if(RK_FLAG_IS_SET(status, kRKReachabilityStatusIsDirect))
        [description appendString:@"kRKReachabilityStatusIsDirect | "];
    if(RK_FLAG_IS_SET(status, kRKReachabilityStatusConnectionAutomatic))
        [description appendString:@"kRKReachabilityStatusConnectionAutomatic | "];
    
    if([description hasSuffix:@" | "]) {
        [description deleteCharactersInRange:NSMakeRange([description length] - 3, 3)];
    }
    
    return [description copy];
}

@implementation RKReachability {
    NSMutableArray *_callbackBlocks;
    SCNetworkReachabilityRef _networkReachability;
}

#pragma mark - Callbacks

static void NetworkReachabilityChanged(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
    RKReachability *self = (__bridge RKReachability *)(info);
    
    [self willChangeValueForKey:@"connectionStatus"];
    [self didChangeValueForKey:@"connectionStatus"];
    
    RK_SYNCHRONIZED_MACONLY(self->_callbackBlocks) {
        for (RKReachabilityStatusChangedBlock statusChangedBlock in self->_callbackBlocks) {
            statusChangedBlock((RKReachabilityStatus)(flags));
        }
    }
}

#pragma mark - Lifecycle

- (void)dealloc
{
    if(_networkReachability) {
        SCNetworkReachabilityUnscheduleFromRunLoop(_networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
        
        CFRelease(_networkReachability);
        _networkReachability = NULL;
    }
}

+ (RKReachability *)defaultInternetConnectionReachability
{
    static RKReachability *defaultInternetConnectionReachability = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct sockaddr_in zeroAddress = {
            .sin_len = sizeof(zeroAddress),
            .sin_family = AF_INET,
        };
        defaultInternetConnectionReachability = [[RKReachability alloc] initWithAddress:(const struct sockaddr *)&zeroAddress];
    });
    
    return defaultInternetConnectionReachability;
}

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithAddress:(const struct sockaddr *)address
{
    NSParameterAssert(address);
    
    if((self = [super init])) {
        _networkReachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, address);
        NSAssert((_networkReachability != NULL), @"Could not create reachability object.");
        
        SCNetworkReachabilityContext context = {
            .version = 0,
            .info = (__bridge void *)(self),
            .retain = &CFRetain,
            .release = &CFRelease,
            .copyDescription = &CFCopyDescription,
        };
        NSAssert(SCNetworkReachabilitySetCallback(_networkReachability, &NetworkReachabilityChanged, &context),
                 @"Could not set reachability callback.");
        
        NSAssert(SCNetworkReachabilityScheduleWithRunLoop(_networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes),
                 @"Could not schedule reachability into main run loop.");
        
        _callbackBlocks = [NSMutableArray new];
    }
    
    return self;
}

#pragma mark - Properties

- (RKReachabilityStatus)connectionStatus
{
    RK_SYNCHRONIZED_MACONLY(self) {
        SCNetworkReachabilityFlags flags = 0;
        if(SCNetworkReachabilityGetFlags(_networkReachability, &flags)) {
            return (RKReachabilityStatus)(flags);
        }
        
        return 0;
    }
}

+ (NSSet *)keyPathsForValuesAffectingIsConnected
{
    return [NSSet setWithObjects:@"connectionStatus", nil];
}

- (BOOL)isConnected
{
    RKReachabilityStatus status = self.connectionStatus;
    
    if(RK_FLAG_IS_SET(status, kRKReachabilityStatusConnectionRequired) ||
       (RK_FLAG_IS_SET(status, kRKReachabilityStatusTransientConnection) && !RK_FLAG_IS_SET(status, kRKReachabilityStatusIsLocalAddress)))
        return NO;
    
    if(!RK_FLAG_IS_SET(status, kRKReachabilityStatusConnectionOnTraffic) &&
       !RK_FLAG_IS_SET(status, kRKReachabilityStatusReachable))
        return NO;
    
    return YES;
}

#pragma mark - Registering Callbacks

- (void)registerStatusChangedBlock:(RKReachabilityStatusChangedBlock)statusChangedBlock
{
    NSParameterAssert(statusChangedBlock);
    
    RK_SYNCHRONIZED_MACONLY(_callbackBlocks) {
        NSAssert(![_callbackBlocks containsObject:statusChangedBlock],
                 @"Cannot register a status changed block more than once.");
        
        [_callbackBlocks addObject:[statusChangedBlock copy]];
    }
}

- (void)unregisterStatusChangedBlock:(RKReachabilityStatusChangedBlock)statusChangedBlock
{
    NSParameterAssert(statusChangedBlock);
    
    RK_SYNCHRONIZED_MACONLY(_callbackBlocks) {
        NSAssert(![_callbackBlocks containsObject:statusChangedBlock],
                 @"Cannot unregister a status changed block that hasn't been registered.");
        
        [_callbackBlocks removeObject:statusChangedBlock];
    }
}

@end
