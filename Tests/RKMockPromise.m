//
//  RKMockPromise.m
//  RoundaboutKitTests
//
//  Created by Kevin MacWhinnie on 5/6/13.
//
//

#import "RKMockPromise.h"

@implementation RKMockPromise

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithResult:(RKPossibility *)result
            duration:(NSTimeInterval)duration
{
    NSParameterAssert(result);
    NSAssert((result.state != kRKPossibilityStateEmpty), @"Cannot pass an empty possibility to RKMockPromise.");
    
    if((self = [super init])) {
        self.result = result;
        self.duration = duration;
    }
    
    return self;
}

#pragma mark - Execution

- (void)fire
{
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.duration * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if(_canceled)
            return;
        
        [self.result whenValue:^(id value) {
            [self accept:value];
        }];
        [self.result whenError:^(NSError *error) {
            [self reject:error];
        }];
    });
}

#pragma mark - <RKCancelable>

@synthesize canceled = _canceled;

- (IBAction)cancel:(id)sender
{
    _canceled = YES;
}

@end
