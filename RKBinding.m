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

@interface RKBinding ()

#pragma mark - Properties

///The target of the binding.
@property (weak) NSObject *target;

///The target key path of the binding.
@property (copy) NSString *targetKeyPath;

///Whether or not the target key path is multi-level.
@property BOOL isTargetKeyPathMultiLevel;

#pragma mark -

///The source of the binding.
@property (assign) __unsafe_unretained NSObject *objectConnectedTo;

///The key path of the source of the binding.
@property (copy) NSString *keyPathConnectedTo;

///Whether or not the source key path is multi-level.
@property BOOL isKeyPathConnectedToMultiLevel;

#pragma mark - Readwrite

///Readwrite.
@property (readwrite) BOOL isConnected;

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
    
    NSAssert(!self.isConnected, @"Cannot connect binding more than once.");
    
    self.objectConnectedTo = object;
    self.keyPathConnectedTo = keyPath;
    self.isKeyPathConnectedToMultiLevel = ([self.keyPathConnectedTo rangeOfString:@"."].location != NSNotFound);
    
    [self.objectConnectedTo addObserver:self forKeyPath:self.keyPathConnectedTo options:0 context:NULL];
    [self.objectConnectedTo.bindings addObject:self];
    
    [self setValue:[self valueForKeyPathFromConnectedToObject:self.keyPathConnectedTo] forKeyPathOnTarget:self.targetKeyPath];
    
    self.isConnected = YES;
    
    return self;
}

- (RKBinding *)disconnect
{
    if(!self.isConnected)
        return self;
    
    [self.objectConnectedTo removeObserver:self forKeyPath:self.keyPathConnectedTo];
    [self.objectConnectedTo.bindings removeObject:self];
    
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
        RKRealize(value, ^(id value) {
            [self setValue:(value && self.valueTransformer? [self.valueTransformer transformedValue:value] : value) forKeyPathOnTarget:self.targetKeyPath];
        }, ^(NSError *error) {
            if(self.promiseFailureBlock)
                self.promiseFailureBlock(error);
            else
                NSLog(@"***Unhandled error from binding-based promise realization: %@", error);
        });
        return self.defaultValue;
    }
    
    return (value && self.valueTransformer? [self.valueTransformer transformedValue:value] : value);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if(object == self.objectConnectedTo && [keyPath isEqualToString:self.keyPathConnectedTo]) {
        [self setValue:[self valueForKeyPathFromConnectedToObject:keyPath] forKeyPathOnTarget:self.targetKeyPath];
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

static CFStringRef const RKBindingsAssociatedObjectKey = CFSTR("RKBindingsAssociatedObjectKey");

@implementation NSObject (RKBinding)

#pragma mark - Automatic Unobservation

+ (void)load
{
    method_exchangeImplementations(class_getInstanceMethod(self, sel_registerName("dealloc")),
                                   class_getInstanceMethod(self, sel_registerName("RKBinding_dealloc")));
}

- (void)RKBinding_dealloc
{
    if(objc_getAssociatedObject(self, RKBindingsAssociatedObjectKey) != nil) {
        NSMutableArray *bindings = self.bindings;
        while (bindings.count > 0) {
            RKBinding *binding = [bindings lastObject];
            [bindings removeLastObject];
            [binding disconnect];
        }
    }
    
    [self RKBinding_dealloc]; //Call the original dealloc
}

#pragma mark - Public Interface

- (RKBinding *)untrackedBindingFor:(NSString *)keyPath
{
    NSParameterAssert(keyPath);
    
    return [[RKBinding alloc] initWithTarget:self keyPath:keyPath];
}

- (RKBinding *)bindingFor:(NSString *)keyPath
{
    NSParameterAssert(keyPath);
    
    RKBinding *binding = [self untrackedBindingFor:keyPath];
    [self.bindings addObject:binding];
    return binding;
}

#pragma mark - Tracking Bindings

- (NSMutableArray *)bindings
{
    NSMutableArray *trackedBindings = objc_getAssociatedObject(self, RKBindingsAssociatedObjectKey);
    if(!trackedBindings) {
        trackedBindings = [NSMutableArray new];
        objc_setAssociatedObject(self, RKBindingsAssociatedObjectKey, trackedBindings, OBJC_ASSOCIATION_RETAIN);
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
