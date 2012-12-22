//
//  RKBlockBasedValueTransformer.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/21/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#ifndef RKBlockBasedValueTransformer_h
#define RKBlockBasedValueTransformer_h 1

#import <Foundation/Foundation.h>
#import "RKPrelude.h"

///Transform a given object to another object.
typedef id(^RKValueTransformerBlock)(id object);

#pragma mark -

///The RKBlockBasedValueTransformer class encapsulates a two block-based value
///transformer subclass designed to make writing quick bindings simpler.
@interface RKBlockBasedValueTransformer : NSValueTransformer

///Initialize the receiver with a transformation and reverse transformation block.
///
/// \param  transformationBlock         The transformation block. Required.
/// \param  reverseTransformationBlock  The reverse transformation block. Optional.
///
/// \result A fully initialized value transformer.
///
///This is the designated initializer.
- (id)initWithTransformationBlock:(RKValueTransformerBlock)transformationBlock
       reverseTransformationBlock:(RKValueTransformerBlock)reverseTransformationBlock;

///Initialize the receiver with a transformation block.
///
/// \param  transformationBlock         The transformation block. Required.
///
/// \result A fully initialized value transformer.
- (id)initWithTransformationBlock:(RKValueTransformerBlock)transformationBlock;

#pragma mark - Properties

///The transformation block.
@property (nonatomic, readonly) RKValueTransformerBlock transformationBlock;

///The reverse transformation block.
@property (nonatomic, readonly) RKValueTransformerBlock reverseTransformationBlock;

@end

#pragma mark -

///Create a new value transformer from blocks.
///
/// \param  transformationBlock         The transformation operation. Required.
/// \param  reverseTransformationBlock  The reverse transformation operation. This parameter may be ommitted.
///
RK_EXTERN_OVERLOADABLE RKBlockBasedValueTransformer *RKMakeValueTransformer(RKValueTransformerBlock transformationBlock);
RK_EXTERN_OVERLOADABLE RKBlockBasedValueTransformer *RKMakeValueTransformer(RKValueTransformerBlock transformationBlock, RKValueTransformerBlock reverseTransformationBlock);

#endif /* RKBlockBasedValueTransformer_h */
