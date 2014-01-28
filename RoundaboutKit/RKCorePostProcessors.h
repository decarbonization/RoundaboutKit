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

@end

#pragma mark -

///Consumes an NSData containing property list data, yields a property list object.
@interface RKPropertyListPostProcessor : RKPostProcessor

@end

#pragma mark -

///Consumes an NSData containing image data, yields an NSImage/UIImage.
@interface RKImagePostProcessor : RKPostProcessor

@end
