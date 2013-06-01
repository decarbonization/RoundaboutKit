//
//  RKURLRequestPromiseCacheManager.h
//  Pinna
//
//  Created by Kevin MacWhinnie on 5/31/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#if RoundaboutKit_EnableCompatibilityPreV10

///Starting in Version 10 of RoundaboutKit the RKURLRequestPromiseCacheManager class
///was refactored into RKFileSystemCacheManager. The method names have remained
///compatible so in order to ease in transitioning to the new class name a compatibility
///alias is provided as well as a forwarding header.

#   warning Deprecated Header

#   import "RKFileSystemCacheManager.h"

#else

#   error Obsoleted Header

#endif /* RoundaboutKit_EnableCompatibilityPreV10 */