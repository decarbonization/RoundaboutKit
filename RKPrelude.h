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
#define RoundaboutKit_Version                     11L

///Whether or not the embedded version of RoundaboutKit is considered stable.
#define RoundaboutKit_Stable                      1

///Whether or not the RoundaboutKit should emit warnings
///for questionable but presently valid behaviour.
#define RoundaboutKit_EmitWarnings                1

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

///Causes any function or method decorated to emit a warning when its return result is not used.
#define RK_REQUIRE_RESULT_USED      __attribute__((warn_unused_result))

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

#pragma mark - • Matching

///Returns the first object in a given collection.
///
///The passed in collection must be array-like and support subscript indexing and have a count method.
RK_EXTERN id RKCollectionGetFirstObject(id collection);

///Returns YES if any value in a given collection passes a specified predicate; NO otherwise.
RK_EXTERN BOOL RKCollectionDoesAnyValueMatch(id input, RKPredicateBlock predicate);

///Returns YES if all values in a given collection pass a specified predicate; NO otherwise.
RK_EXTERN BOOL RKCollectionDoAllValuesMatch(id input, RKPredicateBlock predicate);

///Returns the first object matching a given predicate in a given collection.
RK_EXTERN id RKCollectionFindFirstMatch(id input, RKPredicateBlock predicate);

#pragma mark - Safe Casting

///Perform a cast with a runtime check.
#define RK_CAST(ClassType, ...) ({ id $value = __VA_ARGS__; if($value && ![$value isKindOfClass:[ClassType class]]) [NSException raise:@"RKDynamicCastTypeMismatchException" format:@"%@ is not a %s", $value, #ClassType]; (ClassType *)$value; })

///Perform a cast with a runtime check, yielding nil if there is a type mismatch.
#define RK_TRY_CAST(ClassType, ...) ({ id $value = __VA_ARGS__; if($value && ![$value isKindOfClass:[ClassType class]]) $value = nil; (ClassType *)$value; })

#pragma mark - Utilities

///Returns a BOOL indicating whether or not the current process is running under a debugger.
///
///The result of this function is cached after its initial call.
RK_EXTERN BOOL RKProcessIsRunningInDebugger();

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
///                     This key path may not contain collection operators. Required.
///
/// \result The value for the key assoicated with the `keyPath`.
///
///This function filters out NSNull values.
RK_EXTERN id RKJSONDictionaryGetObjectAtKeyPath(NSDictionary *dictionary, NSString *keyPath);

#pragma mark -

///Returns the MD5 hash of a given string.
///
/// \param  string  The string to get the hash for. May be nil.
///
/// \result An MD5 of the string.
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
RK_EXTERN void RKLog_Internal(const char *prettyFunction, RKLogType type, NSString *format, ...);

#if RKLogEnabled

///Logs a given error message.
///
/// \param  format          A format string. Required.
/// \param  ...             A comma-separated list of arguments to substitute into format.
///
///No-op if `RKGlobalLoggingTypesEnabled` doesn't contain `kRKLogTypeErrors`.
///
///Expands to nothing if `RKLogEnabled` is zero or undefined.
#   define RKLogError(format, ...)     RKLog_Internal(__PRETTY_FUNCTION__, kRKLogTypeErrors, format, ##__VA_ARGS__)

///Logs a given warning message.
///
/// \param  format          A format string. Required.
/// \param  ...             A comma-separated list of arguments to substitute into format.
///
///No-op if `RKGlobalLoggingTypesEnabled` doesn't contain `kRKLogTypeWarnings`.
///
///Expands to nothing if `RKLogEnabled` is zero or undefined.
#   define RKLogWarning(format, ...)   RKLog_Internal(__PRETTY_FUNCTION__, kRKLogTypeWarnings, format, ##__VA_ARGS__)

///Logs a given informative message.
///
/// \param  format          A format string. Required.
/// \param  ...             A comma-separated list of arguments to substitute into format.
///
///No-op if `RKGlobalLoggingTypesEnabled` doesn't contain `kRKLogTypeInfo`.
///
///Expands to nothing if `RKLogEnabled` is zero or undefined.
#   define RKLogInfo(format, ...)      RKLog_Internal(__PRETTY_FUNCTION__, kRKLogTypeInfo, format, ##__VA_ARGS__)

///Logs a trace indicating a certain line in the containing function has been passed.
///
/// \param  format          A format string. Required.
/// \param  ...             A comma-separated list of arguments to substitute into format.
///
///No-op if `RKGlobalLoggingTypesEnabled` doesn't contain `kRKLogTypeInfo`.
///
///Expands to nothing if `RKLogEnabled` is zero or undefined.
#   define RKLogTrace()                RKLog_Internal(__PRETTY_FUNCTION__, kRKLogTypeInfo, @"trace from %d", __LINE__)

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
