//
//  RKPrelude.h
//  NewBrowser
//
//  Created by Kevin MacWhinnie on 2/8/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#ifndef RKPrelude_h
#define RKPrelude_h 1

#import <Foundation/Foundation.h>

///The version of the RoundaboutKit being embedded.
#define RoundaboutKit_Version                           22L

///Whether or not the embedded version of RoundaboutKit is considered stable.
#define RoundaboutKit_Stable                            1

#pragma mark - Compile Time Options

///Whether or not the RoundaboutKit should emit warnings
///for questionable but presently valid behaviour.
#define RoundaboutKit_EmitWarnings                      1

///Whether or not compiler diagnostics for
///deprecated entities should be included.
#define RoundaboutKit_EmitDeprecationWarnings           1

///Whether or not RoundaboutKit should include
///the legacy RKRealize function available.
///
///RKRealize is deprecated and will be removed.
#define RoundaboutKit_EnableLegacyRealization           0

///Whether or not RoundaboutKit should include the
///legacy RKPossibility matching/refining functions.
///
///This functions are deprecated and will be removed.
#define RoundaboutKit_EnableLegacyPossibilityFunctions  0

#pragma mark - Linkage Goop

#if __cplusplus

///Indicates external linkage for a function that uses the C ABI.
#	define RK_EXTERN                extern "C"

///Indicates external link for a function that is overloadable and uses said ABI.
#   define RK_EXTERN_OVERLOADABLE   extern

///Indicates that a function is overloadable.
///
///This attribute changes the ABI of whatever function it is applied to.
///This define should only be used in implementation files.
///
/// \seealso(RK_EXTERN_OVERLOADABLE)
#	define RK_OVERLOADABLE

#else

///Indicates external linkage for a function that uses the C ABI.
#	define RK_EXTERN                extern

///Indicates external link for a function that is overloadable and uses said ABI.
#   define RK_EXTERN_OVERLOADABLE   extern __attribute__((overloadable))

///Indicates that a function is overloadable.
///
///This attribute changes the ABI of whatever function it is applied to.
///This define should only be used in implementation files.
///
/// \seealso(RK_EXTERN_OVERLOADABLE)
#	define RK_OVERLOADABLE          __attribute__((overloadable))

#endif /* __cplusplus */

#define RK_INLINE                   static inline

#pragma mark - Markers

///Causes any function or method decorated to emit a warning when its return result is not used.
#define RK_REQUIRE_RESULT_USED      __attribute__((warn_unused_result))

#if RoundaboutKit_EmitDeprecationWarnings

#   if __has_extension(attribute_deprecated_with_message)
#       define RK_DEPRECATED(_Msg)  __attribute__((deprecated("" _Msg "")))
#   else
#       define RK_DEPRECATED(_Msg)  __attribute__((deprecated))
#   endif /* __has_extension(attribute_deprecated_with_message) */

#   define RK_DEPRECATED_SINCE_2_1     RK_DEPRECATED("Deprecated since RoundaboutKit 2.1")

#else

#   define RK_DEPRECATED
#   define RK_DEPRECATED_SINCE_2_1

#endif /* RoundaboutKit_EmitDeprecationWarnings */

#pragma mark - Thread-Safety Goop

#if TARGET_OS_IPHONE

///Indicates a property is atomic on non-iOS platforms only.
#   define RK_NONATOMIC_IOSONLY         nonatomic

///Indicates that a section of code is only synchronized on the Mac platform.
#   define RK_SYNCHRONIZED_MACONLY(...)

#else

///Indicates a property is atomic on non-iOS platforms only.
#   define RK_NONATOMIC_IOSONLY

///Indicates that a section of code is only synchronized on the Mac platform.
#   define RK_SYNCHRONIZED_MACONLY(...) @synchronized(__VA_ARGS__)

#endif /* TARGET_OS_IPHONE */

#pragma mark - Tools

///Whether or not a flag is set on a bitfield.
///	\param	field	The field to check for the flag on.
///	\param	flag	The flag.
#define RK_FLAG_IS_SET(field, flag) ((flag & field) == flag)

#pragma mark - Time Tools

///The number of seconds in a minute.
#define RK_TIME_MINUTE	(60.0)

///The number of seconds in an hour.
#define RK_TIME_HOUR	(RK_TIME_MINUTE * 60.0)

///The number of seconds in a day.
#define RK_TIME_DAY		(RK_TIME_HOUR * 24.0)

///The number of seconds in a week.
#define RK_TIME_WEEK	(RK_TIME_DAY * 7.0)

#pragma mark -

///An infinitely large time interval.
RK_EXTERN NSTimeInterval const kRKTimeIntervalInfinite;

///Returns a human readable time stamp for a given time interval.
///
///If the time interval is negative, this function returns `@"Continuous"`.
RK_EXTERN NSString *RKMakeStringFromTimeInterval(NSTimeInterval total);

#pragma mark - Collection Operations

///A Generator is a block that takes an index and returns an object.
typedef id(^RKGeneratorBlock)(NSUInteger index);

///A Predicate is a block that takes an object and applies a test to it, returning the result.
typedef BOOL(^RKPredicateBlock)(id value);

///A Mapper is a block that takes an object and performs an operation on it, returning the result.
typedef id(^RKMapperBlock)(id value);

///A reducer is a block that takes an accumulator and a value, and returns the sum of both.
typedef id(^RKReducerBlock)(id accumulator, id value);

#pragma mark - • Generation

///Returns a newly generated array of a given length.
RK_EXTERN NSArray *RKCollectionGenerateArray(NSUInteger length, RKGeneratorBlock generator);

#pragma mark - • Mapping

///Returns a collection mapped to an array.
RK_EXTERN NSArray *RKCollectionMapToArray(id input, RKMapperBlock mapper);

///Returns a collection mapped to a mutable array.
RK_EXTERN NSMutableArray *RKCollectionMapToMutableArray(id input, RKMapperBlock mapper);

///Returns a collection mapped to an ordered set.
RK_EXTERN NSOrderedSet *RKCollectionMapToOrderedSet(id input, RKMapperBlock mapper);

#pragma mark - • Filtering

///Returns a given collection filtered into an array.
RK_EXTERN NSArray *RKCollectionFilterToArray(id input, RKPredicateBlock predicate);

#pragma mark - • Reducing

///Returns a reduced form of a given collection.
RK_EXTERN id RKCollectionReduce(id input, RKReducerBlock reducer);

#pragma mark - • Matching

///Returns the first object in a given collection.
///
///The passed in collection must be array-like and support subscript indexing and have a count method.
RK_EXTERN id RKCollectionGetFirstObject(id collection) RK_DEPRECATED("Deprecated since RoundaboutKit 2.2. Use -[NSArray firstObject] instead.");

///Returns YES if any value in a given collection passes a specified predicate; NO otherwise.
RK_EXTERN BOOL RKCollectionDoesAnyValueMatch(id input, RKPredicateBlock predicate);

///Returns YES if all values in a given collection pass a specified predicate; NO otherwise.
RK_EXTERN BOOL RKCollectionDoAllValuesMatch(id input, RKPredicateBlock predicate);

///Returns the first object matching a given predicate in a given collection.
RK_EXTERN id RKCollectionFindFirstMatch(id input, RKPredicateBlock predicate);

#pragma mark - • Deep Copying

///Returns a new array that contains a copy of each element in the given input.
///
/// \param  input   An object implementing <NSFastEnumeration> whose elements
///                 are NSObjects implementing <NSCopying>. Optional.
///
/// \result A new array with copies of each element of the input.
///
RK_EXTERN NSArray *RKCollectionDeepCopy(id input);

#pragma mark - Safe Casting

/*
 *  These functions cause the deprecated RK_CAST and RK_TRY_CAST to emit warnings
 *  at compile-time. Both legacy macros will be removed at a future date.
 */
RK_DEPRECATED("RK_CAST is deprecated. Use RK_CAST_OR_THROW instead.") RK_INLINE void RKCastDeprecated(void) {}
RK_DEPRECATED("RK_TRY_CAST is deprecated. Use RK_CAST_OR_NIL instead.") RK_INLINE void RKTryCastDeprecated(void) {}

///Perform a cast with a runtime check.
#define RK_CAST_OR_THROW(ClassType, ...)    ({ id $value = __VA_ARGS__; if($value && ![$value isKindOfClass:[ClassType class]]) [NSException raise:@"RKDynamicCastTypeMismatchException" format:@"%@ is not a %s", $value, #ClassType]; (ClassType *)$value; })
#define RK_CAST(ClassType, ...)             ({ RKCastDeprecated(); RK_CAST_OR_THROW(ClassType, __VA_ARGS__); }) //deprecated

///Perform a cast with a runtime check, yielding nil if there is a type mismatch.
#define RK_CAST_OR_NIL(ClassType, ...)  ({ id $value = __VA_ARGS__; if($value && ![$value isKindOfClass:[ClassType class]]) $value = nil; (ClassType *)$value; })
#define RK_TRY_CAST(ClassType, ...)     ({ RKTryCastDeprecated(); RK_CAST_OR_NIL(ClassType, __VA_ARGS__); }) //deprecated

#pragma mark - Utilities

///Returns a BOOL indicating whether or not the current process is running under a debugger.
///
///The result of this function is cached after its initial call.
RK_EXTERN BOOL RKProcessIsRunningInDebugger() RK_DEPRECATED("Deprecated since RoundaboutKit 2.2. RKProcessIsRunningInDebugger no longer works.");

#pragma mark -

///Returns an NSString sans 'the' at the beginning.
RK_EXTERN NSString *RKSanitizeStringForSorting(NSString *string);

///Combines an array of NSString objects into a string suitable for use
///as a universal identifier or is an inexpensive comparator.
///
/// \param  strings     The strings to combine into the identifier. Required.
///
/// \result The `strings` combined and sanitized.
///
///The result of this method is safe to use as a file system name.
///
///This function is the the replacement for the obsoleted `RKGenerateSongID` function.
RK_EXTERN NSString *RKGenerateIdentifierForStrings(NSArray *strings);

#pragma mark -

///Returns `nil` if `value` is NSNull, `value` otherwise.
RK_INLINE id RKFilterOutNSNull(id value)
{
	if(value == [NSNull null])
		return nil;
	
	return value;
}

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
///it safe to traverse deep Json structures without worrying about a null exception.
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
/// - (NSDictionary)data.(NSString)lastName
/// - (NSDictionary)data.(NSArray)associates.{if SELF[SIZE] > 0}
///
///__Important:__ this function currently only supports traversing NSDictionaries.
RK_EXTERN id RKTraverseJson(NSDictionary *dictionary, NSString *enhancedKeyPath, NSError **outError);

#pragma mark -

///Returns the MD5 hash of a given string.
///
/// \param  string  The string to calculate the hash for. May be nil.
///
/// \result An MD5 hash of the string.
///
///__Important:__ This function will be deprecated in a future version.
RK_EXTERN NSString *RKStringGetMD5Hash(NSString *string);

#pragma mark -

///A block used to convert a value into a string suitable for inclusion in URL Parameters.
typedef NSString *(^RKURLParameterStringifier)(id value);

///The default value stringifier.
///
///This stringifier supports strings and numbers and will convert arrays and dictionaries into JSON.
RK_EXTERN RKURLParameterStringifier kRKURLParameterStringifierDefault;

///Returns a URL-encoded copy of a specified string using stricter rules than `-[NSString stringByAddingPercentEscapesUsingEncoding:]`.
///
/// \param  string      The string to encode. May be nil.
/// \param  encoding    The encoding to use for the resultant string.
///
/// \result A URL ready copy of the passed in string.
RK_EXTERN NSString *RKStringEscapeForInclusionInURL(NSString *string, NSStringEncoding encoding);

///Returns a URL query string composed of a specified dictionary.
///
/// \param  parameters          A dictionary whose keys and values are NSStrings.
/// \param  valueStringifier    The block to use to convert the values into NSStrings. This parameter may be omitted.
///
/// \result A string representing the passed in dictionary.
RK_EXTERN_OVERLOADABLE NSString *RKDictionaryToURLParametersString(NSDictionary *parameters, RKURLParameterStringifier valueStringifier);
RK_EXTERN_OVERLOADABLE NSString *RKDictionaryToURLParametersString(NSDictionary *parameters);

#pragma mark - Logging

///Set to 1 to enable the RKLog mechanism.
#define RKLogEnabled    1

///The different types of log messages that can be emitted.
typedef NS_OPTIONS(NSUInteger, RKLogType) {
    ///Error messages.
    kRKLogTypeErrors = (1 << 1),
    
    ///Warning messages.
    kRKLogTypeWarnings = (1 << 2),
    
    ///Info messages.
    kRKLogTypeInfo = (1 << 3),
    
    
    ///All of the different types of log messages.
    kRKLogTypeAll = (kRKLogTypeErrors | kRKLogTypeWarnings | kRKLogTypeInfo)
};

///A bit-or'd value describing which types of log messages that should
///be emitted. Any types omitted from the value will not be logged.
///
///This global is only intended to be changed once
///very early on in the host application's lifecycle.
///The default value of this global is `kRKLogTypeAll`.
RK_EXTERN RKLogType RKGlobalLoggingTypesEnabled;

///The block type used to implement logging hooks in the RKLog mechanism.
///
/// \param  type    The type of message being logged.
/// \param  message The message being logged. This string is the result
///                 of evaluating format+varargs on the RKLog functions.
///
///Thread hook blocks may be invoked from any thread.
///Hooks do not filter based on what types are enabled. If a hook
///is only interested in loggings that are currently enabled for console
///output, it should compare `type` against `RKGlobalLoggingTypesEnabled`.
///
/// \seealso(RKLogAddHook)
typedef void(^RKLogHookBlock)(RKLogType type, const char *prettyFunction, int line, NSString *message);

///The primitive logging function used by all RK logging macros. Conditionally
///prints a given format-string and its arguments to `stderr` if the given
///logging level is within the scope of the current global logging level.
///
/// \param  prettyFunction  The function which the log function is being invoked from. Required.
/// \param  type            The type of message being logged. Must not be `kNilOptions` or `kRKLogTypeAll`.
/// \param  format          A format string. Required.
/// \param  ...             A comma-separated list of arguments to substitute into format.
///
///This function should never be invoked directly, but always through one the `RKLog` macros.
RK_EXTERN void RKLog_Internal(const char *prettyFunction, int line, RKLogType type, NSString *format, ...) NS_FORMAT_FUNCTION(4, 5);

///Adds a block to be executed every time one of the RKLog function-like is invoked.
///Log hook blocks are invoked before the logging information is passed along to NSLog.
///
/// \param  hookBlock   The hook block. Required.
///
///##Important:
///It is not safe to invoke this function from anything but the main thread.
RK_EXTERN void RKLogAddHook(RKLogHookBlock hookBlock);

#if RKLogEnabled

///Logs a given error message.
///
/// \param  format          A format string. Required.
/// \param  ...             A comma-separated list of arguments to substitute into format.
///
///No-op if `RKGlobalLoggingTypesEnabled` doesn't contain `kRKLogTypeErrors`.
///
///Expands to nothing if `RKLogEnabled` is zero or undefined.
#   define RKLogError(format, ...)     RKLog_Internal(__PRETTY_FUNCTION__, __LINE__, kRKLogTypeErrors, format, ##__VA_ARGS__)

///Logs a given warning message.
///
/// \param  format          A format string. Required.
/// \param  ...             A comma-separated list of arguments to substitute into format.
///
///No-op if `RKGlobalLoggingTypesEnabled` doesn't contain `kRKLogTypeWarnings`.
///
///Expands to nothing if `RKLogEnabled` is zero or undefined.
#   define RKLogWarning(format, ...)   RKLog_Internal(__PRETTY_FUNCTION__, __LINE__, kRKLogTypeWarnings, format, ##__VA_ARGS__)

///Logs a given informative message.
///
/// \param  format          A format string. Required.
/// \param  ...             A comma-separated list of arguments to substitute into format.
///
///No-op if `RKGlobalLoggingTypesEnabled` doesn't contain `kRKLogTypeInfo`.
///
///Expands to nothing if `RKLogEnabled` is zero or undefined.
#   define RKLogInfo(format, ...)      RKLog_Internal(__PRETTY_FUNCTION__, __LINE__, kRKLogTypeInfo, format, ##__VA_ARGS__)

///Logs a trace indicating a certain line in the containing function has been passed.
///
/// \param  format          A format string. Required.
/// \param  ...             A comma-separated list of arguments to substitute into format.
///
///No-op if `RKGlobalLoggingTypesEnabled` doesn't contain `kRKLogTypeInfo`.
///
///Expands to nothing if `RKLogEnabled` is zero or undefined.
#   define RKLogTrace()                RKLog_Internal(__PRETTY_FUNCTION__, __LINE__, kRKLogTypeInfo, @"trace")

#else
#   define RKLogError(format, ...)
#   define RKLogWarning(format, ...)
#   define RKLogInfo(format, ...)
#   define RKLogTrace()
#endif /* RKLogEnabled */

#pragma mark - Mac Image Tools

#if TARGET_OS_MAC && defined(_APPKITDEFINES_H)

///Returns the data for the specified image in PNG format.
RK_EXTERN_OVERLOADABLE NSData *NSImagePNGRepresentation(NSImage *image);

///Returns the data for the specified image in PNG format.
RK_EXTERN_OVERLOADABLE NSData *NSImageJPGRepresentation(NSImage *image);

#endif /* TARGET_OS_MAC && defined(_APPKITDEFINES_H) */

#endif /* RKPrelude_h */
