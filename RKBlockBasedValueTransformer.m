//
//  RKBlockBasedValueTransformer.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/21/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#import "RKBlockBasedValueTransformer.h"

@interface RKBlockBasedValueTransformer ()

///Readwrite
@property (nonatomic, readwrite) RKValueTransformerBlock transformationBlock;

///Readwrite
@property (nonatomic, readwrite) RKValueTransformerBlock reverseTransformationBlock;

@end

@implementation RKBlockBasedValueTransformer

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

#pragma mark - Lifecycle

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return self;
}

- (id)initWithTransformationBlock:(RKValueTransformerBlock)transformationBlock
       reverseTransformationBlock:(RKValueTransformerBlock)reverseTransformationBlock
{
    NSParameterAssert(transformationBlock);
    
    if((self = [super init])) {
        self.transformationBlock = transformationBlock;
        self.reverseTransformationBlock = reverseTransformationBlock;
    }
    
    return self;
}

- (id)initWithTransformationBlock:(RKValueTransformerBlock)transformationBlock
{
    return [self initWithTransformationBlock:transformationBlock reverseTransformationBlock:nil];
}

#pragma mark - Transformation

- (id)reverseTransformedValue:(id)value
{
    if(self.reverseTransformationBlock)
        return self.reverseTransformationBlock(value);
    
    return value;
}

- (id)transformedValue:(id)value
{
    return self.transformationBlock(value);
}

@end

#pragma mark -

RK_OVERLOADABLE RKBlockBasedValueTransformer *RKMakeValueTransformer(RKValueTransformerBlock transformationBlock)
{
    NSCParameterAssert(transformationBlock);
    
    return RKMakeValueTransformer(transformationBlock, nil);
}

RK_OVERLOADABLE RKBlockBasedValueTransformer *RKMakeValueTransformer(RKValueTransformerBlock transformationBlock, RKValueTransformerBlock reverseTransformationBlock)
{
    NSCParameterAssert(transformationBlock);
    
    return [[RKBlockBasedValueTransformer alloc] initWithTransformationBlock:transformationBlock
                                                  reverseTransformationBlock:reverseTransformationBlock];
}
