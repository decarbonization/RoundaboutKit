//
//  RunLoopHelper.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import "RKRunLoopTestHelper.h"

@implementation RKRunLoopTestHelper

+ (void)runFor:(NSTimeInterval)seconds
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

+ (BOOL)runUntil:(BOOL(^)())predicate orSecondsHasElapsed:(NSTimeInterval)seconds
{
    NSParameterAssert(predicate);
    
    NSDate *startTime = [NSDate date];
    BOOL lessThanStartTime = YES;
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (!predicate() &&
           (lessThanStartTime = (-[startTime timeIntervalSinceNow] < seconds)) &&
           [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
    
    return lessThanStartTime;
}

@end
