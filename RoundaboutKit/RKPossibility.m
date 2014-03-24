//
//  RKPossibility.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/20/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#import "RKPossibility.h"

@implementation RKPossibility {
	id _value;
	NSError *_error;
    RKPossibilityState _state;
}

#pragma mark - Convenience

+ (instancetype)possibilityWithValue:(id)value;
{
    return [[self alloc] initWithValue:value];
}

+ (instancetype)possibilityWithError:(NSError *)error
{
    return [[self alloc] initWithError:error];
}

+ (instancetype)emptyPossibility
{
    static RKPossibility *emptyPossibility = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        emptyPossibility = [[RKPossibility alloc] initEmpty];
    });
    
    return emptyPossibility;
}

#pragma mark -

+ (NSArray *)valuesFromPossibilities:(NSArray *)possibilities
{
    return RKCollectionMapToArray(possibilities, ^id(RKPossibility *maybeValue) {
        if(maybeValue.state == kRKPossibilityStateValue)
            return maybeValue.value;
        else
            return nil;
    });
}

+ (NSArray *)errorsFromPossibilities:(NSArray *)possibilities
{
    return RKCollectionMapToArray(possibilities, ^id(RKPossibility *maybeError) {
        if(maybeError.state == kRKPossibilityStateError)
            return maybeError.error;
        else
            return nil;
    });
}

#pragma mark - Lifecycle

- (id)initWithValue:(id)value
{
	if((self = [super init])) {
		_value = value;
        _state = kRKPossibilityStateValue;
	}
	
	return self;
}

- (id)initWithError:(NSError *)error
{
	if((self = [super init])) {
		_error = error;
        _state = kRKPossibilityStateError;
	}
	
	return self;
}

- (id)initEmpty
{
    if((self = [super init])) {
        _state = kRKPossibilityStateEmpty;
    }
    
    return self;
}

- (id)init
{
    return [self initEmpty];
}

#pragma mark - Properties

@synthesize value = _value;
@synthesize error = _error;
@synthesize state = _state;

#pragma mark - Refining

- (RKPossibility *)refineValue:(RKPossibility *(^)(id value))refiner
{
    NSParameterAssert(refiner);
    
    if(self.state != kRKPossibilityStateValue)
        return self;
    
    return refiner(self.value);
}

- (RKPossibility *)refineError:(RKPossibility *(^)(NSError *error))refiner
{
    NSParameterAssert(refiner);
    
    if(self.state != kRKPossibilityStateError)
        return self;
    
    return refiner(self.error);
}

- (RKPossibility *)refineEmpty:(RKPossibility *(^)())refiner
{
    NSParameterAssert(refiner);
    
    if(self.state != kRKPossibilityStateEmpty)
        return self;
    
    return refiner();
}

#pragma mark - Matching

- (void)whenValue:(void(^)(id value))matcher
{
    NSParameterAssert(matcher);
    
    if(self.state == kRKPossibilityStateValue)
        matcher(self.value);
}

- (void)whenError:(void(^)(NSError *error))matcher
{
    NSParameterAssert(matcher);
    
    if(self.state == kRKPossibilityStateError)
        matcher(self.error);
}

- (void)whenEmpty:(void(^)())matcher
{
    NSParameterAssert(matcher);
    
    if(self.state == kRKPossibilityStateEmpty)
        matcher();
}

@end

#if RoundaboutKit_EnableLegacyPossibilityFunctions

RKPossibility *(^kRKPossibilityDefaultValueRefiner)(id) = nil;
RKPossibility *(^kRKPossibilityDefaultEmptyRefiner)() = nil;
RKPossibility *(^kRKPossibilityDefaultErrorRefiner)(NSError *) = nil;

void(^kRKPossibilityDefaultValueMatcher)(id) = nil;
void(^kRKPossibilityDefaultEmptyMatcher)() = nil;
void(^kRKPossibilityDefaultErrorMatcher)(NSError *) = nil;

RK_OVERLOADABLE RKPossibility *RKRefinePossibility(RKPossibility *possibility,
                                                   RKPossibility *(^valueRefiner)(id value),
                                                   RKPossibility *(^emptyRefiner)(),
                                                   RKPossibility *(^errorRefiner)(NSError *error))
{
    if(!possibility)
        return nil;
    
    if(!valueRefiner) valueRefiner = ^(id value) { return [[RKPossibility alloc] initWithValue:value]; };
    if(!emptyRefiner) emptyRefiner = ^{ return [[RKPossibility alloc] initEmpty]; };
    if(!errorRefiner) errorRefiner = ^(NSError *error) { return [[RKPossibility alloc] initWithError:error]; };
    
    if(possibility.state == kRKPossibilityStateValue) {
        return valueRefiner(possibility.value);
    } else if(possibility.state == kRKPossibilityStateEmpty) {
        return emptyRefiner();
    } else if(possibility.state == kRKPossibilityStateError) {
        return errorRefiner(possibility.error);
    }
    
    NSCAssert(0, @"RKPossibility is in an undefined state.");
    
    return nil;
}

RK_OVERLOADABLE void RKMatchPossibility(RKPossibility *possibility,
                                        void(^value)(id value),
                                        void(^empty)(),
                                        void(^error)(NSError *error))
{
    if(!possibility)
        return;
    
    if(possibility.state == kRKPossibilityStateValue) {
        if(value)
            value(possibility.value);
    } else if(possibility.state == kRKPossibilityStateEmpty) {
        if(empty)
            empty();
    } else if(possibility.state == kRKPossibilityStateError) {
        if(error)
            error(possibility.error);
    } else {
        NSCAssert(0, @"RKPossibility is in an undefined state.");
    }
}

#endif /* RoundaboutKit_EnableLegacyPossibilityFunctions */
