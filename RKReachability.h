//
//  RKReachability.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/31/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#ifndef RKReachability_h
#define RKReachability_h 1

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

///Flags that indicate the reachability of a network node name or address.
///
/// \seealso(SCNetworkReachabilityFlags)
typedef enum RKReachabilityStatus : SCNetworkReachabilityFlags {
    /// \seealso(kSCNetworkReachabilityFlagsTransientConnection)
    kRKReachabilityStatusTransientConnection = kSCNetworkReachabilityFlagsTransientConnection,
    
    /// \seealso(kSCNetworkReachabilityFlagsReachable)
    kRKReachabilityStatusReachable = kSCNetworkReachabilityFlagsReachable,
    
    /// \seealso(kSCNetworkReachabilityFlagsConnectionRequired)
    kRKReachabilityStatusConnectionRequired = kSCNetworkReachabilityFlagsConnectionRequired,
    
    /// \seealso(kSCNetworkReachabilityFlagsConnectionOnTraffic)
    kRKReachabilityStatusConnectionOnTraffic = kSCNetworkReachabilityFlagsConnectionOnTraffic,
    
    /// \seealso(kSCNetworkReachabilityFlagsInterventionRequired)
    kRKReachabilityStatusInterventionRequired = kSCNetworkReachabilityFlagsInterventionRequired,
    
    /// \seealso(kSCNetworkReachabilityFlagsConnectionOnDemand)
    kRKReachabilityStatusConnectionOnDemand = kSCNetworkReachabilityFlagsConnectionOnDemand,
    
    /// \seealso(kSCNetworkReachabilityFlagsIsLocalAddress)
    kRKReachabilityStatusIsLocalAddress = kSCNetworkReachabilityFlagsIsLocalAddress,
    
    /// \seealso(kSCNetworkReachabilityFlagsIsDirect)
    kRKReachabilityStatusIsDirect = kSCNetworkReachabilityFlagsIsDirect,
    
    /// \seealso(kSCNetworkReachabilityFlagsConnectionAutomatic)
    kRKReachabilityStatusConnectionAutomatic = kSCNetworkReachabilityFlagsConnectionAutomatic,
} RKReachabilityStatus;

///Returns a descriptive string for a reachability status value.
RK_EXTERN NSString *RKReachabilityStatusGetDescription(RKReachabilityStatus status);

///A reachability statuc changed block.
typedef void(^RKReachabilityStatusChangedBlock)(RKReachabilityStatus connectionStatus);

///The RKReachability class encapsulates internet connectivity state tracking.
///
///This object requires there be an active run loop to function.
@interface RKReachability : NSObject

///Returns the default internet connection reachability object, creating it if it does not exist.
+ (RKReachability *)defaultInternetConnectionReachability;

///Initialize the recevier with a given socket address.
///
/// \param  address The address. Required.
///
/// \result A fully initialized RKReachability object.
///
///This is the designated initializer of RKReachability.
- (id)initWithAddress:(const struct sockaddr *)address;

#pragma mark - Properties

///The current connection status.
@property (readonly, RK_NONATOMIC_IOSONLY) RKReachabilityStatus connectionStatus;

///Whether or not we're connected.
@property (readonly, RK_NONATOMIC_IOSONLY) BOOL isConnected;

#pragma mark - Registering Callbacks

///Register a status changed block.
- (void)registerStatusChangedBlock:(RKReachabilityStatusChangedBlock)statusChangedBlock;

///Unregister a status changed block.
- (void)unregisterStatusChangedBlock:(RKReachabilityStatusChangedBlock)statusChangedBlock;

@end

#endif /* RKReachability_h */
