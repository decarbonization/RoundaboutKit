//
//  RKURLRequestPromiseCacheManager.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 1/7/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import "RKURLRequestPromise.h"

///The RKURLRequestPromiseCacheManager class encapsulates a simple file
///system based cache manager for use with RKURLRequestPromises.
///
///Instances of RKURLRequestPromiseCacheManager are asynchronously initialized
///to reduce the cost of calling `+[RKURLRequestPromiseCacheManager sharedCacheManagerForBucket]`.
///Instances' access methods will block until initialization has been completed.
@interface RKURLRequestPromiseCacheManager : NSObject <RKURLRequestPromiseCacheManager>

///Returns the shared cache manager for a given bucket, creating it if it does not exist.
///
///This method call is relatively expensive, and as such the result should be
///assigned to a property or ivar of the class that is asking for a cache manager.
+ (RKURLRequestPromiseCacheManager *)sharedCacheManagerForBucket:(NSString *)bucketName;

#pragma mark - Properties

///The name of the bucket associated with this cache manager.
@property (readonly, copy) NSString *bucketName;

@end
