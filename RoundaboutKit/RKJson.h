//
//  RKJson.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 3/18/14.
//  Copyright (c) 2014 Roundabout Software, LLC. All rights reserved.
//

#ifndef RoundaboutKit_RKJson_h
#define RoundaboutKit_RKJson_h

#import "RKPrelude.h"

///Safely indexes a JSON dictionary given a limited keyPath.
///
/// \param  dictionary  The dictionary to index. Optional.
/// \param  keyPath     The key path to search for in the dictionary.
///
/// \result The value for the key assoicated with the `keyPath`.
///
///This function filters out NSNull values.
///
///Starting in RoundaboutKit 2.2, this function is an alias for RKTraverseJson,
///and as such supports the enhanced key path type safety and predicate syntax.
///
///__Important:__ This function will be deprecated in a future version.
RK_EXTERN id RKJSONDictionaryGetObjectAtKeyPath(NSDictionary *dictionary, NSString *keyPath);

///The error domain used by the RKTraverseJson class.
RK_EXTERN NSString *const RKJsonTraversingErrorDomain;

///The exception type used by RKTraverseJson.
RK_EXTERN NSString *const RKJsonTraversingException;

///The error codes used by the RKJsonTraversingErrorDomain domain.
NS_ENUM(NSInteger, RKJsonTraversingErrorCode) {
    ///Indicates that a type assertion was not satisfied.
    kRKJsonTraversingErrorCodeTypeUnsatisfied = 'type',
    
    ///Indicates that a null leaf was encountered.
    kRKJsonTraversingErrorCodeNullEncountered = 'null',
    
    ///Indicates that a condition predicate was unsatisfied.
    kRKJsonTraversingErrorCodeConditionUnsatisifed = '!tru',
};

///Traverses a Json dictionary using a given enhanced key path.
///
/// \param  dictionary      The dictionary to traverse.
/// \param  enhancedKeyPath An enhaneced key path to traverse the dictionary with. Required.
/// \param  error           On return, contains an error that describes any short circuit that occurred.
///
/// \result The value for the key path if no null leafs were encountered,
///         *and* all of the assertions were satisfied; nil otherwise.
///
/// \throws NSInternalInconsistencyException when the key path contains unbalanced curly
///         brackets, an @keyPath operator is found, a non-existent class is referenced,
///         or a condition assertion is found at the beginning of a key path.
///
///The enhanced key path this function takes is an imperfect super-set of the syntax used
///by `-[NSObject valueForKeyPath:]`, described in the sections below.
///
///Null Handling:
///==============
///
///Any time either nil or NSNull is encountered while traversing a path, the traversal is
///immediately terminated, and the function will return nil with an out error. This makes
///it safe to traverse deep Json structures without worrying about a null exception. If a
///value may safely be null/nil, the key path component may be suffixed with a question mark.
///E.g. `data.(NSString)firstName?` will return nil if first name is null/nil, but will not
///set the error parameter.
///
///Assertions:
///===========
///
///There are two types of assertions: Type assertions, and condition assertions.
///
///Type assertions are placed before a path component, like `(NSString)firstName`.
///If the path component is not of the type specified, traversing is aborted and
///nil is returned with an out error.
///
///Condition assertions are always placed immediately after the path component they
///are applied to, and are evaluated by NSPredicate. E.g. `associates.{if SELF[SIZE] > 0}`.
///When a predicate is applied to an array, it is evaluated against each object in the array.
///As such, the predicate must be true for every item in order for the condition to pass.
///If the predicate passes, the object from the path to the left of the predicate is used.
///Otherwise, the function will return nil and an out error.
///
///Operators:
///==========
///
///The enhanced key path syntax currently does not support the @keyPath operators provided
///by the Foundation framework. These may be added at a future date.
///
///Examples:
///=========
///
/// - data.firstName
/// - (NSDictionary)data.(NSString)firstName
/// - (NSDictionary)data.(NSString)lastName?
/// - (NSDictionary)data.(NSArray)associates.{if SELF[SIZE] > 0}
///
///__Important:__ this function currently only supports traversing NSDictionaries.
RK_EXTERN id RKTraverseJson(NSDictionary *dictionary, NSString *enhancedKeyPath, NSError **outError);

#endif
