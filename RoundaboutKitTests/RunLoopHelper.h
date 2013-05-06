//
//  RunLoopHelper.h
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import <Foundation/Foundation.h>

///The RunLoopHelper class contains methods to assist in tests
///which require the main runloop to be running to complete.
@interface RunLoopHelper : NSObject

///Runs the main run loop for n seconds.
///
/// \param  seconds The number of seconds to run the run loop for.
///
+ (void)runFor:(NSTimeInterval)seconds;

///Runs the main run loop until the given predicate yields NO.
///
/// \param  predicate   A block which returns a BOOL indicating whether or not the run loop should continue. Required.
///
+ (void)runUntil:(BOOL(^)())predicate;

@end
