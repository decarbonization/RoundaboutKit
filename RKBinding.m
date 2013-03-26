//
//  RKBinding.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/18/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#import "RKBinding.h"
#import "RKPrelude.h"

#import <objc/runtime.h>

#pragma mark - Warnings

void RKBindingEmitUnhandledRealizationErrorWarning(NSError *error)
{
#if RoundaboutKit_EmitWarnings
    NSLog(@"*** Warning, unhandled error from binding-based promise realization. Existing connection was broken. Add a breakpoint to RKBindingEmitUnhandledRealizationErrorWarning to debug. Error: %@", error);
#endif /* RoundaboutKit_EmitWarnings */
}

#pragma mark - Continuations

@interface NSObject (RKBinding_Continued)

@property (readonly, nonatomic) NSMutableArray *bindingsTrackedForLifecycle;

@end

#pragma mark -

@interface RKBinding ()

///Initialize the receiver with a specified target and key path.
///
/// \param  target  The object this binding will be to. Required.
/// \param  keyPath The key path of the object that will be bound to another object. Required.
///
/// \result A fully initialized RKBinding object.
///
- (id)initWithTarget:(__weak NSObject *)target keyPath:(NSString *)keyPath;

#pragma mark - Properties

///The target of the binding.
@property (assign, RK_NONATOMIC_IOSONLY) __unsafe_unretained NSObject *target;

///The target key path of the binding.
@property (copy, RK_NONATOMIC_IOSONLY) NSString *targetKeyPath;

///Whether or not the target key path is multi-level.
@property (RK_NONATOMIC_IOSONLY) BOOL isTargetKeyPathMultiLevel;

#pragma mark -

///The source of the binding.
@property (assign, RK_NONATOMIC_IOSONLY) __unsafe_unretained NSObject *objectConnectedTo;

///The key path of the source of the binding.
@property (copy, RK_NONATOMIC_IOSONLY) NSString *keyPathConnectedTo;

///Whether or not the source key path is multi-level.
@property (RK_NONATOMIC_IOSONLY) BOOL isKeyPathConnectedToMultiLevel;

///The promise currently being realized.
@property RKPromise *currentPromise;

#pragma mark - Readwrite

///Readwrite.
@property (readwrite, RK_NONATOMIC_IOSONLY) BOOL isConnected;

///Readwrite
@property (readwrite, RK_NONATOMIC_IOSONLY) RKBindingConnectionType connectionType;

@end

#pragma mark -

@implementation RKBinding {
    NSValueTransformer *_valueTransformer;
}

#pragma mark - Lifecycle

- (void)dealloc
{
    if(_isConnected)
        [_objectConnectedTo removeObserver:self forKeyPath:_keyPathConnectedTo];
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
        self.isTargetKeyPathMultiLevel = ([self.targetKeyPath rangeOfString:@"."].location != NSNotFound);
        
        self.realizePromises = YES;
    }
    
    return self;
}

#pragma mark - Connections

- (RKBinding *)connectTo:(NSObject *)object keyPath:(NSString *)keyPath
{
    NSParameterAssert(object);
    NSParameterAssert(keyPath);
    
    if(self.isConnected) {
        [self disconnect];
    }
    
    self.objectConnectedTo = object;
    self.keyPathConnectedTo = keyPath;
    self.isKeyPathConnectedToMultiLevel = ([self.keyPathConnectedTo rangeOfString:@"."].location != NSNotFound);
    
    [self.objectConnectedTo addObserver:self forKeyPath:self.keyPathConnectedTo options:0 context:NULL];
    [self.objectConnectedTo.bindingsTrackedForLifecycle addObject:self];
    
    [self setValue:[self valueForKeyPathFromConnectedToObject:self.keyPathConnectedTo] forKeyPathOnTarget:self.targetKeyPath];
    
    self.isConnected = YES;
    
    self.connectionType = kRKBindingConnectionTypeOneWayBinding;
    
    return self;
}

- (RKBinding *)disconnect
{
    if(!self.isConnected)
        return self;
    
    [self.objectConnectedTo removeObserver:self forKeyPath:self.keyPathConnectedTo];
    [self.objectConnectedTo.bindingsTrackedForLifecycle removeObject:self];
    
    self.objectConnectedTo = nil;
    self.keyPathConnectedTo = nil;
    
    self.isConnected = NO;
    
    return self;
}

#pragma mark - Observation

- (void)setValue:(id)value forKeyPathOnTarget:(NSString *)keyPath
{
    if(_isTargetKeyPathMultiLevel)
        [_target setValue:value forKeyPath:keyPath];
    else
        [_target setValue:value forKey:keyPath];
}

- (id)valueForKeyPathFromConnectedToObject:(NSString *)keyPath
{
    id value = nil;
    if(_isKeyPathConnectedToMultiLevel)
        value = [_objectConnectedTo valueForKeyPath:keyPath] ?: _defaultValue;
    else
        value = [_objectConnectedTo valueForKey:keyPath] ?: _defaultValue;
    
    if(_realizePromises && [value isKindOfClass:[RKPromise class]]) {
        RKPromise *promise = value;
        
        [self.currentPromise cancel:nil];
        self.currentPromise = promise;
        
        NSAssert(![promise isMultiPart], @"Multi-part promises are not supported by RKBinding.");
        
        RKRealize(promise, ^(id realizedValue) {
            if(promise == self.currentPromise)
                self.currentPromise = nil;
            else
                return;
            
            [self setValue:(realizedValue && _valueTransformer? [_valueTransformer transformedValue:realizedValue] : realizedValue) forKeyPathOnTarget:_targetKeyPath];
        }, ^(NSError *error) {
            if(promise == self.currentPromise)
                self.currentPromise = nil;
            else
                return;
            
            if(_promiseFailureBlock)
                _promiseFailureBlock(error);
            else
                RKBindingEmitUnhandledRealizationErrorWarning(error);
        });
        
        return _defaultValue;
    }
    
    return (value && _valueTransformer? [_valueTransformer transformedValue:value] : value);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if(object == _objectConnectedTo && [keyPath isEqualToString:_keyPathConnectedTo]) {
        switch (_connectionType) {
            case kRKBindingConnectionTypeOneWayBinding: {
                [self setValue:[self valueForKeyPathFromConnectedToObject:keyPath] forKeyPathOnTarget:_targetKeyPath];
                break;
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Properties

- (void)setValueTransformer:(NSValueTransformer *)valueTransformer
{
    NSAssert([[valueTransformer class] allowsReverseTransformation],
             @"Cannot use one-way value transformer %@", valueTransformer);
    
    @synchronized(self) {
        _valueTransformer = valueTransformer;
    }
}

- (NSValueTransformer *)valueTransformer
{
    @synchronized(self) {
        return _valueTransformer;
    }
}

@end

#pragma mark -

static CFStringRef const RKBindingsTrackedForLifecycleAssociatedObjectKey = CFSTR("RKBindingsTrackedForLifecycleAssociatedObjectKey");

RK_INLINE void InstallRKBindingDealloc()
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class NSObjectClass = [NSObject class];
        
        method_exchangeImplementations(class_getInstanceMethod(NSObjectClass, sel_registerName("dealloc")),
                                       class_getInstanceMethod(NSObjectClass, sel_registerName("RKBinding_dealloc")));
    });
}

@implementation NSObject (RKBinding)

#pragma mark - Automatic Unobservation

- (void)RKBinding_dealloc
{
    NSMutableArray *bindings = objc_getAssociatedObject(self, RKBindingsTrackedForLifecycleAssociatedObjectKey);
    if(bindings != nil) {
        for (RKBinding *binding in bindings) {
            if(binding.isConnected) {
                [binding.objectConnectedTo removeObserver:binding forKeyPath:binding.keyPathConnectedTo];
                binding.isConnected = NO;
            }
        }
    }
    
    [self RKBinding_dealloc]; //Call the original dealloc
}

#pragma mark - Public Interface

- (RKBinding *)bindingFor:(NSString *)keyPath
{
    NSParameterAssert(keyPath);
    
    NSMutableArray *bindingsTrackedForLifecycle = self.bindingsTrackedForLifecycle;
    RKBinding *binding = RKCollectionFindFirstMatch(bindingsTrackedForLifecycle, ^BOOL(RKBinding *binding) {
        return (binding.target == self) && [binding.targetKeyPath isEqualToString:keyPath];
    });
    if(!binding) {
        binding = [[RKBinding alloc] initWithTarget:self keyPath:keyPath];
        [bindingsTrackedForLifecycle addObject:binding];
    }
    return binding;
}

#pragma mark - Tracking Bindings

///The mutable array returned by this method is used to track the
///lifecycle of bindings for both target and connected-to objects.
///
///The return value of this method is to be considered an implementation
///detail, and this method should never be publicly exposed.
- (NSMutableArray *)bindingsTrackedForLifecycle
{
    InstallRKBindingDealloc();
    
    NSMutableArray *trackedBindings = objc_getAssociatedObject(self, RKBindingsTrackedForLifecycleAssociatedObjectKey);
    if(!trackedBindings) {
        trackedBindings = [NSMutableArray new];
        objc_setAssociatedObject(self, RKBindingsTrackedForLifecycleAssociatedObjectKey, trackedBindings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return trackedBindings;
}

@end

#pragma mark -

@implementation NSArray (RKBinding)

- (NSArray *)bindingsFor:(NSString *)keyPath
{
    return RKCollectionMapToArray(self, ^id(id value) {
        return [value bindingFor:keyPath];
    });
}

@end

#pragma mark - One-Off Observations

///The RKOneTimeObserver encapsulates a one-time observation.
@interface RKOneTimeObserver : NSObject

///Initialize the receiver with a given target, key path, and callback block.
///
/// \param  target      Required.
/// \param  keyPath     Required.
/// \param  callback    Required.
///
/// \result A fully initialized one time observer.
///
- (id)initWithTarget:(id)target keyPath:(NSString *)keyPath callback:(void(^)(id value))callback;

#pragma mark - Properties

@property id target;
@property (copy) NSString *keyPath;
@property (copy) void(^callback)(id value);

@end

@implementation RKOneTimeObserver

- (void)dealloc
{
    [self.target removeObserver:self forKeyPath:self.keyPath];
}

- (id)initWithTarget:(id)target keyPath:(NSString *)keyPath callback:(void(^)(id value))callback
{
    NSParameterAssert(target);
    NSParameterAssert(keyPath);
    NSParameterAssert(callback);
    
    if((self = [super init])) {
        self.target = target;
        self.keyPath = keyPath;
        self.callback = callback;
        
        [self.target addObserver:self forKeyPath:self.keyPath options:0 context:NULL];
    }
    
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if(object == self.target && [keyPath isEqualToString:self.keyPath]) {
        [self.target removeObserver:self forKeyPath:self.keyPath];
        
        self.callback(object);
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end

#pragma mark -

RK_OVERLOADABLE id RKObserveOnce(id target, NSString *keyPath, void(^callback)(id value))
{
    NSCParameterAssert(target);
    NSCParameterAssert(keyPath);
    NSCParameterAssert(callback);
    
    return [[RKOneTimeObserver alloc] initWithTarget:target
                                             keyPath:keyPath
                                            callback:callback];
}
