//
//  RKPossibility.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/20/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#ifndef RKPossibility_h
#define RKPossibility_h 1

#import <Foundation/Foundation.h>
#import "RKPrelude.h"

///The different types of contents an RKPossibility can contain.
typedef enum RKPossibiltyContents : NSUInteger {
    
    ///The possibility contains nothing.
    kRKPossibiltyContentsEmpty = 0,
    
    ///The possibility contains a value.
    kRKPossibiltyContentsValue = 1,
    
    ///The possibility contains an error.
    kRKPossibiltyContentsError = 2,
    
} RKPossibiltyContents;

///The RKPossibility class represents the two possible outcomes of a given promise.
@interface RKPossibility : NSObject
{
	id mValue;
	NSError *mError;
    RKPossibiltyContents mContents;
}

///Initialize the receiver with a specified value.
- (id)initWithValue:(id)value;

///Initialize the receiver with a specified error.
- (id)initWithError:(NSError *)error;

///Initialize the receiver with nothing.
- (id)initEmpty;

#pragma mark - Properties

///The possible value.
@property (readonly) id value;

///The possible error.
@property (readonly) NSError *error;

@property (readonly) RKPossibiltyContents contents;

@end

///Refine a possibility by passing its contents through a refiner block.
///
/// \param  possibility     The possibility to refine. Optional.
/// \param  valueRefiner    The block to invoke when the possibility is a `value`. Optional.
/// \param  errorRefiner    The block to invoke when the possibility is an `error`. Optional.
///
/// \result A new possibility whose contents have been passed through a refiner.
///
///function RefinePossibility(possibility) = match(possibility) {
/// id(value) -> return valueRefiner(value);
/// NSError(value) -> return errorRefiner(error);
///}
RK_EXTERN_OVERLOADABLE RKPossibility *RKRefinePossibility(RKPossibility *possibility,
                                                          id(^valueRefiner)(id value),
                                                          NSError *(^errorRefiner)(NSError *error));

///Match a possibility's contents against `value` and `error` blocks.
///
/// \param  possibility The possibility to match. Optional.
/// \param  value       The block to invoke when the possibility is a `value`. Optional.
/// \param  error       The block to invoke when the possibility is an `error`. Optional.
///
///function RefinePossibility(possibility) = match(possibility) {
/// id(value) -> value(value);
/// NSError(value) -> error(error);
///}
RK_EXTERN_OVERLOADABLE void RKMatchPossibility(RKPossibility *possibility,
                                               void(^value)(id value),
                                               void(^error)(NSError *error));

#endif /* RKPossibility_h */
