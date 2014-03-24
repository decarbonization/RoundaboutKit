//
//  RKJson.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 3/18/14.
//  Copyright (c) 2014 Roundabout Software, LLC. All rights reserved.
//

#import "RKJson.h"

NSString *const RKJsonTraversingErrorDomain = @"RKJsonTraversingErrorDomain";
NSString *const RKJsonTraversingException = @"RKJsonTraversingException";


///The separator token used by enhanced key paths.
static NSString *const kSeparator = @".";

///The operator prefix used by enhanced key path operators.
static NSString *const kOperatorPrefix = @"@";

///The suffix used by enhanced key paths to mark a path component as optional.
static NSString *const kOptionalSuffix = @"?";


///The token that marks the beginning of a type cast.
static NSString *const kTypeStart = @"(";

///The token that marks the end of a type cast.
static NSString *const kTypeEnd = @")";


///The token that marks the beginning of an assertion.
static NSString *const kAssertionStart = @"{";

///The token that marks the end of an assertion.
static NSString *const kAssertionEnd = @"}";

///The prefix that marks an assertion condition.
static NSString *const kAssertionConditionPrefix = @"if ";


#pragma mark - Internal

///Splits a string containing an advanced key path, taking
///into account that dots may appear within assertions.
static NSArray *TokenizeEnhancedKeyPath(NSString *enhancedKeyPath)
{
    NSCParameterAssert(enhancedKeyPath);
    
    NSMutableArray *tokens = [NSMutableArray array];
    
    __block NSUInteger anchorPoint = 0;
    __block NSUInteger nestedDirectivesCount = 0;
    __block NSUInteger typeAnchorPoint = NSNotFound;
    __block NSString *type = nil;
    [enhancedKeyPath enumerateSubstringsInRange:NSMakeRange(0, enhancedKeyPath.length) options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        if([substring isEqualToString:kSeparator] && nestedDirectivesCount == 0) {
            NSRange tokenRange = NSMakeRange(anchorPoint, substringRange.location - anchorPoint);
            NSString *token = [enhancedKeyPath substringWithRange:tokenRange];
            [tokens addObject:token];
            if(type) {
                [tokens addObject:type];
                type = nil;
            }
            anchorPoint = NSMaxRange(substringRange);
        } else if([substring isEqualToString:kTypeStart]) {
            typeAnchorPoint = substringRange.location;
        } else if([substring isEqualToString:kTypeEnd]) {
            if(typeAnchorPoint == NSNotFound) {
                [NSException raise:NSInternalInconsistencyException
                            format:@"Unexpected closing type parenthesis in enhanced key path %@ at offset %lu", enhancedKeyPath, (unsigned long)substringRange.location];
            }
            
            NSRange typeRange = NSMakeRange(typeAnchorPoint, NSMaxRange(substringRange) - typeAnchorPoint);
            type = [enhancedKeyPath substringWithRange:typeRange];
            anchorPoint = NSMaxRange(typeRange);
            typeAnchorPoint = NSNotFound;
        } else if([substring isEqualToString:kAssertionStart]) {
            nestedDirectivesCount++;
        } else if([substring isEqualToString:kAssertionEnd]) {
            if(nestedDirectivesCount == 0)
                [NSException raise:NSInternalInconsistencyException
                            format:@"Unexpected closing assertion curly brace in enhanced key path %@ at offset %lu", enhancedKeyPath, (unsigned long)substringRange.location];
            nestedDirectivesCount--;
        }
    }];
    
    if(nestedDirectivesCount != 0)
        [NSException raise:NSInternalInconsistencyException
                    format:@"Expected closing assertion curly brace, found end of string instead."];
    
    if(typeAnchorPoint != NSNotFound)
        [NSException raise:NSInternalInconsistencyException
                    format:@"Expected closing parenthesis, found end of string instead."];
    
    if(anchorPoint < enhancedKeyPath.length) {
        NSString *finalToken = [enhancedKeyPath substringWithRange:NSMakeRange(anchorPoint, enhancedKeyPath.length - anchorPoint)];
        [tokens addObject:finalToken];
        
        if(type) {
            [tokens addObject:type];
        }
    }
    
    return tokens;
}

///Evaluates a predicate assertion component of an enhanced key path.
///
/// \param  value       The value that will be tested against. Required.
/// \param  component   The path component to evaluate. This function assumes that
///                     the component has already been checked for basic validity. Required.
/// \param  error       On return, contains any evaluation errors.
///
/// \result YES if the predicate assertion evaluated to true; NO otherwise.
///
///This function assumes it will be passed a string that starts and ends with curly braces,
///and that its position is valid within the containing enhanced key path. These tests must
///be performed by the calling function.
static BOOL EvaluateEnhancedKeyPathPredicateAssertion(id value, NSString *component, NSError **error)
{
    NSCParameterAssert(value);
    NSCParameterAssert(component);
    
    NSRange assertionRange = NSMakeRange(kAssertionStart.length, component.length - (kAssertionStart.length + kAssertionEnd.length));
    NSString *assertion = [component substringWithRange:assertionRange];
    if([assertion hasPrefix:kAssertionConditionPrefix]) {
        NSString *condition = [assertion substringFromIndex:kAssertionConditionPrefix.length];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:condition argumentArray:@[]];
        if(![predicate evaluateWithObject:value]) {
            NSString *localizedDescription = [NSString stringWithFormat:@"Object %@ failed to satisfy condition %@", value, condition];
            if(error) *error = [NSError errorWithDomain:RKJsonTraversingErrorDomain
                                                   code:kRKJsonTraversingErrorCodeConditionUnsatisifed
                                               userInfo:@{NSLocalizedDescriptionKey: localizedDescription}];
            return NO;
        }
    } else {
        [NSException raise:RKJsonTraversingException
                    format:@"RKTraverseJson does not recognize assertion %@.", assertion];
    }
    
    return YES;
}

///Evaluates a type assertion component of an enhanced key path.
///
/// \param  value   The value that will be tested against. Required.
/// \param  component   The path component to evaluate. This function assumes that
///                     the component has already been checked for basic validity. Required.
/// \param  error       On return, contains any evaluation errors.
///
/// \result YES if the value is of type 'component'; NO otherwise.
///
///This function assumes it will be passed a string that starts and ends with parentheses,
///and that its position is valid within the containing enhanced key path. These tests must
///be performed by the calling function.
static BOOL EvaluateEnhancedKeyPathTypeAssertion(id value, NSString *component, NSError **error)
{
    NSCParameterAssert(value);
    NSCParameterAssert(component);
    
    NSRange typeRange = NSMakeRange(kTypeStart.length, component.length - (kTypeStart.length + kTypeEnd.length));
    NSString *type = [component substringWithRange:typeRange];
    
    if([type isEqualToString:@"id"]) {
        RKLogWarning(@"Unnecessary id type assertion in enhanced key path.");
        return YES;
    }
    
    Class class = NSClassFromString(type);
    if(class == Nil) {
        [NSException raise:RKJsonTraversingException
                    format:@"RKTraverseJson encountered class with name %@ that does not exist.", type];
    }
    
    if(![value isKindOfClass:class]) {
        NSString *localizedDescription = [NSString stringWithFormat:@"Object %@ was not of expected type %@", value, type];
        if(error) *error = [NSError errorWithDomain:RKJsonTraversingErrorDomain
                                               code:kRKJsonTraversingErrorCodeTypeUnsatisfied
                                           userInfo:@{NSLocalizedDescriptionKey: localizedDescription}];
        return NO;
    } else {
        return YES;
    }
}

#pragma mark - Public

id RKTraverseJson(NSDictionary *dictionary, NSString *enhancedKeyPath, NSError **outError)
{
    NSCParameterAssert(enhancedKeyPath);
    
    if(!RKFilterOutNSNull(dictionary))
        return nil;
    
    NSError *error = nil;
    NSArray *components = TokenizeEnhancedKeyPath(enhancedKeyPath);
    id value = dictionary;
    for (NSString *component in components) {
        if([component hasPrefix:kOperatorPrefix]) {
            [NSException raise:RKJsonTraversingException
                        format:@"RKTraverseJson does not support @keyPath operators."];
        } else if([component hasPrefix:kAssertionStart] && [component hasSuffix:kAssertionEnd]) {
            if(!value || value == dictionary) {
                [NSException raise:RKJsonTraversingException
                            format:@"RKTraverseJson does not support assertions at the beginning of a key path."];
            }
            
            if(!EvaluateEnhancedKeyPathPredicateAssertion(value, component, &error)) {
                value = nil;
                break;
            }
        } else if([component hasPrefix:kTypeStart] && [component hasSuffix:kTypeEnd]) {
            if(!EvaluateEnhancedKeyPathTypeAssertion(value, component, &error)) {
                value = nil;
                break;
            }
        } else {
            NSString *key = component;
            
            BOOL wantsError = YES;
            if([key hasSuffix:kOptionalSuffix]) {
                key = [key substringFromIndex:kOptionalSuffix.length];
                wantsError = NO;
            }
            value = RKFilterOutNSNull([value objectForKey:key]);
            
            if(!value) {
                if(wantsError) error = [NSError errorWithDomain:RKJsonTraversingErrorDomain
                                                           code:kRKJsonTraversingErrorCodeNullEncountered
                                                       userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Object for %@ was nil", component]}];
                break;
            }
        }
    }
    
    if(error) {
        if(outError)
            *outError = error;
        else
            RKLogWarning(@"Unhandled unsatisfied path. Error: %@", error);
    }
    
    return value;
}
