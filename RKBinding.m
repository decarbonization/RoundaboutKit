//
//  RKBinding.m
//  Pinna
//
//  Created by Kevin MacWhinnie on 12/18/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#import "RKBinding.h"

@interface RKBinding ()

#pragma mark - Properties

///The target of the binding.
@property (weak) NSObject *target;

///The target key path of the binding.
@property (copy) NSString *targetKeyPath;

#pragma mark -

///The source of the binding.
@property NSObject *source;

///The key path of the source of the binding.
@property (copy) NSString *sourceKeyPath;

#pragma mark - Readwrite

///Readwrite.
@property (readwrite) BOOL isConnected;

@end

#pragma mark -

@implementation RKBinding

#pragma mark - Lifecycle

- (void)dealloc
{
    [self.source removeObserver:self forKeyPath:self.sourceKeyPath];
}

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithTarget:(__weak NSObject *)target keyPath:(NSString *)keyPath
{
    NSParameterAssert(target);
    NSParameterAssert(keyPath);
    
    if((self = [super init])) {
        self.target = target;
        self.targetKeyPath = keyPath;
    }
    
    return self;
}

#pragma mark - Connections

- (RKBinding *)connectTo:(NSObject *)object keyPath:(NSString *)keyPath
{
    NSParameterAssert(object);
    NSParameterAssert(keyPath);
    
    NSAssert(!self.isConnected, @"Cannot connect binding more than once.");
    
    self.source = object;
    self.sourceKeyPath = keyPath;
    
    [self.source addObserver:self forKeyPath:self.sourceKeyPath options:0 context:NULL];
    
    [self.target setValue:[self.source valueForKey:self.sourceKeyPath] forKey:self.targetKeyPath];
    
    self.isConnected = YES;
    
    return self;
}

- (RKBinding *)disconnect
{
    if(!self.isConnected)
        return self;
    
    [self.source removeObserver:self forKeyPath:self.sourceKeyPath];
    
    self.source = nil;
    self.sourceKeyPath = nil;
    
    self.isConnected = NO;
    
    return self;
}

#pragma mark - Observation

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if(object == self.source && [keyPath isEqualToString:self.sourceKeyPath]) {
        [self.target setValue:[object valueForKey:keyPath] forKey:self.targetKeyPath];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

#pragma mark -

@implementation NSObject (RKBinding)

- (RKBinding *)untrackedBindingFor:(NSString *)keyPath
{
    return [[RKBinding alloc] initWithTarget:self keyPath:keyPath];
}

- (RKBinding *)bindingFor:(NSString *)keyPath
{
    RKBinding *binding = [self untrackedBindingFor:keyPath];
    [self.bindings addObject:binding];
    return binding;
}

#pragma mark - Tracking Bindings

- (NSMutableArray *)bindings
{
    NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
    NSMutableArray *trackedBindings = threadDictionary[@"com.roundabout.NSObject_RKBinding.trackedBindings"];
    if(!trackedBindings) {
        trackedBindings = [NSMutableArray new];
        threadDictionary[@"com.roundabout.NSObject_RKBinding.trackedBindings"] = trackedBindings;
    }
    
    return trackedBindings;
}

@end
