//
//  RKParameters.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/19/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import "RKRequestParameters.h"

@interface RKRequestParameters ()

///The underlying storage for the parameters.
@property (nonatomic) NSMutableDictionary *parameters;

#pragma mark - readwrite

@property (nonatomic, readwrite) RKRequestParametersNilHandlingMode nilHandlingMode;

@end

#pragma mark -

@implementation RKRequestParameters

#pragma mark - Lifecycle

- (instancetype)initWithNilHandlingMode:(RKRequestParametersNilHandlingMode)mode
{
    if((self = [super init])) {
        self.parameters = [NSMutableDictionary dictionary];
        self.nilHandlingMode = mode;
    }
    
    return self;
}

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma mark - Identity

- (NSUInteger)hash
{
    return self.class.hash ^ self.parameters.hash + (NSUInteger)self.nilHandlingMode;
}

- (BOOL)isEqual:(id)object
{
    if([object isKindOfClass:[RKRequestParameters class]]) {
        RKRequestParameters *other = (RKRequestParameters *)object;
        return ([self.parameters isEqualToDictionary:other.parameters] &&
                self.nilHandlingMode == other.nilHandlingMode);
    }
    
    return NO;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@:%p %@>", NSStringFromClass(self.class), self, self.parameters];
}

#pragma mark - Getting and Setting Parameters

- (void)setObject:(id)object forKey:(NSString *)key
{
    NSParameterAssert(key);
    
    if(!object) {
        switch (self.nilHandlingMode) {
            case RKRequestParametersNilHandlingModeThrow:
                [NSException raise:NSInvalidArgumentException format:@"nil value for key %@ is unsupported.", key];
                break;
                
            case RKRequestParametersNilHandlingModeIgnore:
                return;
                
            case RKRequestParametersNilHandlingModeSubstituteEmptyString:
                object = @"";
                break;
                
            case RKRequestParametersNilHandlingModeSubstituteNSNull:
                object = [NSNull null];
                break;
        }
    }
    
    [self willChangeValueForKey:key];
    self.parameters[key] = object;
    [self didChangeValueForKey:key];
}

- (id)objectForKey:(NSString *)key
{
    NSParameterAssert(key);
    return self.parameters[key];
}

#pragma mark - Conversions

- (NSDictionary *)dictionaryRepresentation
{
    return [self.parameters copy];
}

#pragma mark - Subscripting Support

- (id)objectForKeyedSubscript:(NSString *)key
{
    return [self objectForKey:key];
}

- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key
{
    NSParameterAssert(key);
    
    [self setObject:obj forKey:key];
}

#pragma mark - KVC Support

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
    [self setObject:value forKey:key];
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return [self objectForKey:key];
}

@end
