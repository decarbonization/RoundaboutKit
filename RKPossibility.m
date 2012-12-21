//
//  RKPossibility.m
//  Pinna
//
//  Created by Kevin MacWhinnie on 12/20/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#import "RKPossibility.h"

@implementation RKPossibility

- (id)initWithValue:(id)value
{
	if((self = [super init]))
	{
		mValue = value;
	}
	
	return self;
}

- (id)initWithError:(NSError *)error
{
	if((self = [super init]))
	{
		mError = error;
	}
	
	return self;
}

#pragma mark - Properties

@synthesize value = mValue;
@synthesize error = mError;

@end

RK_OVERLOADABLE RKPossibility *RKRefinePossibility(RKPossibility *possibility,
                                                   id(^valueRefiner)(id value),
                                                   NSError *(^errorRefiner)(NSError *error))
{
    if(!possibility)
        return nil;
    
    if(!valueRefiner) valueRefiner = ^(id value) { return value; };
    if(!errorRefiner) errorRefiner = ^(NSError *error) { return error; };
    
    if(possibility.value)
    {
        return [[RKPossibility alloc] initWithValue:valueRefiner(possibility.value)];
    }
    else if(possibility.error)
    {
        return [[RKPossibility alloc] initWithError:errorRefiner(possibility.error)];
    }
    
    NSCAssert(0, @"RKPossibility is in an undefined state.");
    
    return nil;
}

RK_OVERLOADABLE void RKMatchPossibility(RKPossibility *possibility,
                                        void(^value)(id value),
                                        void(^error)(NSError *error))
{
    if(!possibility)
        return;
    
    if(possibility.value)
    {
        if(value)
            value(possibility.value);
    }
    else if(possibility.error)
    {
        if(error)
            error(possibility.error);
    }
    
    NSCAssert(0, @"RKPossibility is in an undefined state.");
}
