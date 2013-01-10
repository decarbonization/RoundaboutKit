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
@property (readonly, nonatomic) NSMutableDictionary *bindingsLookupTable;

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
@property (weak, RK_NONATOMIC_IOSONLY) NSObject *target;

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
    [self.objectConnectedTo removeObserver:self forKeyPath:self.keyPathConnectedTo];
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

- (RKBinding *)becomeAffectedBy:(NSObject *)object keyPath:(NSString *)keyPath
{
    NSParameterAssert(object);
    NSParameterAssert(keyPath);
    
    NSAssert(!self.isConnected, @"Cannot connect binding more than once.");
    
    self.objectConnectedTo = object;
    self.keyPathConnectedTo = keyPath;
    self.isKeyPathConnectedToMultiLevel = ([self.keyPathConnectedTo rangeOfString:@"."].location != NSNotFound);
    
    [self.objectConnectedTo addObserver:self forKeyPath:self.keyPathConnectedTo options:0 context:NULL];
    [self.objectConnectedTo.bindingsTrackedForLifecycle addObject:self];
    
    self.isConnected = YES;
    
    self.connectionType = kRKBindingConnectionTypeChangePropagation;
    
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
    if(self.isTargetKeyPathMultiLevel)
        [self.target setValue:value forKeyPath:keyPath];
    else
        [self.target setValue:value forKey:keyPath];
}

- (id)valueForKeyPathFromConnectedToObject:(NSString *)keyPath
{
    id value = nil;
    if(self.isKeyPathConnectedToMultiLevel)
        value = [self.objectConnectedTo valueForKeyPath:keyPath] ?: self.defaultValue;
    else
        value = [self.objectConnectedTo valueForKey:keyPath] ?: self.defaultValue;
    
    if(self.realizePromises && [value isKindOfClass:[RKPromise class]]) {
        RKPromise *promise = value;
        
        [self.currentPromise cancel:nil];
        self.currentPromise = promise;
        
        if([promise isKindOfClass:[RKMultiPartPromise class]]) {
            RKRealizeMultiPart((RKMultiPartPromise *)promise, ^(id realizedValue, RKMultiPartPromisePart fromPart) {
                if(promise == self.currentPromise)
                    self.currentPromise = nil;
                else
                    return;
                
                [self setValue:(realizedValue && self.valueTransformer? [self.valueTransformer transformedValue:realizedValue] : realizedValue) forKeyPathOnTarget:self.targetKeyPath];
            }, ^(NSError *error, RKMultiPartPromisePart fromPart) {
                if(promise == self.currentPromise)
                    self.currentPromise = nil;
                else
                    return;
                
                if(self.promiseFailureBlock)
                    self.promiseFailureBlock(error);
                else
                    RKBindingEmitUnhandledRealizationErrorWarning(error);
            });
        } else {
            RKRealize(promise, ^(id realizedValue) {
                if(promise == self.currentPromise)
                    self.currentPromise = nil;
                else
                    return;
                
                [self setValue:(realizedValue && self.valueTransformer? [self.valueTransformer transformedValue:realizedValue] : realizedValue) forKeyPathOnTarget:self.targetKeyPath];
            }, ^(NSError *error) {
                if(promise == self.currentPromise)
                    self.currentPromise = nil;
                else
                    return;
                
                if(self.promiseFailureBlock)
                    self.promiseFailureBlock(error);
                else
                    RKBindingEmitUnhandledRealizationErrorWarning(error);
            });
        }
        return self.defaultValue;
    }
    
    return (value && self.valueTransformer? [self.valueTransformer transformedValue:value] : value);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if(object == self.objectConnectedTo && [keyPath isEqualToString:self.keyPathConnectedTo]) {
        switch (self.connectionType) {
            case kRKBindingConnectionTypeOneWayBinding: {
                [self setValue:[self valueForKeyPathFromConnectedToObject:keyPath] forKeyPathOnTarget:self.targetKeyPath];
                break;
            }
                
            case kRKBindingConnectionTypeChangePropagation: {
                [self.target willChangeValueForKey:self.targetKeyPath];
                [self.target didChangeValueForKey:self.targetKeyPath];
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
static CFStringRef const RKBindingsLookupTableAssociatedObjectKey = CFSTR("RKBindingsLookupTableAssociatedObjectKey");

@implementation NSObject (RKBinding)

#pragma mark - Automatic Unobservation

+ (void)load
{
    method_exchangeImplementations(class_getInstanceMethod(self, sel_registerName("dealloc")),
                                   class_getInstanceMethod(self, sel_registerName("RKBinding_dealloc")));
}

- (void)RKBinding_dealloc
{
    if(objc_getAssociatedObject(self, RKBindingsTrackedForLifecycleAssociatedObjectKey) != nil) {
        NSMutableArray *bindings = self.bindingsTrackedForLifecycle;
        while (bindings.count > 0) {
            RKBinding *binding = [bindings lastObject];
            [bindings removeLastObject];
            [binding disconnect];
        }
    }
    
    [self RKBinding_dealloc]; //Call the original dealloc
}

#pragma mark - Public Interface

- (RKBinding *)bindingFor:(NSString *)keyPath
{
    NSParameterAssert(keyPath);
    
    NSMutableDictionary *existentBindings = self.bindingsLookupTable;
    
    RKBinding *binding = existentBindings[keyPath];
    if(!binding) {
        binding = [[RKBinding alloc] initWithTarget:self keyPath:keyPath];
        existentBindings[keyPath] = binding;
    }
    [self.bindingsTrackedForLifecycle addObject:binding];
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
    NSMutableArray *trackedBindings = objc_getAssociatedObject(self, RKBindingsTrackedForLifecycleAssociatedObjectKey);
    if(!trackedBindings) {
        trackedBindings = [NSMutableArray new];
        objc_setAssociatedObject(self, RKBindingsTrackedForLifecycleAssociatedObjectKey, trackedBindings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return trackedBindings;
}

///The mutable dictionary returned by this method is
///used to track bindings by key path for an object.
- (NSMutableDictionary *)bindingsLookupTable
{
    NSMutableDictionary *bindingsLookupTable = objc_getAssociatedObject(self, RKBindingsLookupTableAssociatedObjectKey);
    if(!bindingsLookupTable) {
        bindingsLookupTable = [NSMutableDictionary new];
        objc_setAssociatedObject(self, RKBindingsLookupTableAssociatedObjectKey, bindingsLookupTable, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    return bindingsLookupTable;
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
