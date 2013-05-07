//
//  RunLoopHelper.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import "RunLoopHelper.h"

@implementation RunLoopHelper

+ (void)runFor:(NSTimeInterval)seconds
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]];
}

+ (void)runUntil:(BOOL(^)())predicate
{
    NSParameterAssert(predicate);
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (!predicate() && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
}

@end
