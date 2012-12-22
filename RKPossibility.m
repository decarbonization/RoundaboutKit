//
//  RKPossibility.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/20/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#import "RKPossibility.h"

@implementation RKPossibility

- (id)initWithValue:(id)value
{
	if((self = [super init])) {
		mValue = value;
        mContents = kRKPossibiltyContentsValue;
	}
	
	return self;
}

- (id)initWithError:(NSError *)error
{
	if((self = [super init])) {
		mError = error;
        mContents = kRKPossibiltyContentsError;
	}
	
	return self;
}

- (id)initEmpty
{
    if((self = [super init])) {
        mContents = kRKPossibiltyContentsEmpty;
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
    
    if(possibility.contents == kRKPossibiltyContentsValue ||
       possibility.contents == kRKPossibiltyContentsEmpty) {
        return [[RKPossibility alloc] initWithValue:valueRefiner(possibility.value)];
    } else if(possibility.contents == kRKPossibiltyContentsError) {
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
    
    if(possibility.contents == kRKPossibiltyContentsValue ||
       possibility.contents == kRKPossibiltyContentsEmpty) {
        if(value)
            value(possibility.value);
    } else if(possibility.contents == kRKPossibiltyContentsError) {
        if(error)
            error(possibility.error);
    }
    
    NSCAssert(0, @"RKPossibility is in an undefined state.");
}
