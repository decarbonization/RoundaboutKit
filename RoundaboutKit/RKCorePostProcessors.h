//
//  RKCorePostProcessors.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 1/28/14.
//  Copyright (c) 2014 Roundabout Software, LLC. All rights reserved.
//

#import "RKPostProcessor.h"

///Consumes an NSData containing JSON, yields a JSON object.
@interface RKJSONPostProcessor : RKPostProcessor

///Returns the shared post processor, creating it if it does not already exist.
+ (instancetype)sharedPostProcessor;

@end

#pragma mark -

///Consumes an NSData containing property list data, yields a property list object.
@interface RKPropertyListPostProcessor : RKPostProcessor

///Returns the shared post processor, creating it if it does not already exist.
+ (instancetype)sharedPostProcessor;

@end

#pragma mark -

///Consumes an NSData containing image data, yields an NSImage/UIImage.
@interface RKImagePostProcessor : RKPostProcessor

///Returns the shared post processor, creating it if it does not already exist.
+ (instancetype)sharedPostProcessor;

@end

#pragma mark -

///Consumes any object, and yields an object specified upon initialization.
@interface RKSingleValuePostProcessor : RKPostProcessor

///Initialize the receiver with an object to return when
///the receiver is called upon to process a value.
- (instancetype)initWithObject:(id)object;

#pragma mark -

@property (nonatomic, readonly) id object;

@end
