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
#define RoundaboutKit_Version       7L

///Whether or not the embedded version of RoundaboutKit is considered stable.
#define RoundaboutKit_Stable        1

///Whether or not the RoundaboutKit should emit warnings
///for questionable but presently valid behaviour.
#define RoundaboutKit_EmitWarnings  1

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

///This method is deprecated and should not be used in new code.
///
///Returns a dictionary mapped.
DEPRECATED_ATTRIBUTE RK_EXTERN NSDictionary *RKDictionaryMap(NSDictionary *input, RKMapperBlock mapper);

#pragma mark - • Filtering

///Returns a given collection filtered into an array.
RK_EXTERN NSArray *RKCollectionFilterToArray(id input, RKPredicateBlock predicate);

#pragma mark - • Matching

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
///This function should be considered the functional replacement for
///the deprecated (and soon to be obsoleted) `RKGenerateSongID` function.
RK_EXTERN NSString *RKGenerateIdentifierForStrings(NSArray *strings);

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

///Retains a given object implementing the `<NSObject>` protocol.
///
///This function should be considered unsafe.
RK_INLINE id RKObjectRetain(id <NSObject> object)
{
    //So we don't have to include the objc runtime headers.
    extern id objc_msgSend(id, SEL, ...);
    
    return objc_msgSend(object, NSSelectorFromString(@"retain"));
}

///Autoreleases a given object implementing the `<NSObject>` protocol.
///
///This function should be considered unsafe.
RK_INLINE id RKObjectAutorelease(id <NSObject> object)
{
    //So we don't have to include the objc runtime headers.
    extern id objc_msgSend(id, SEL, ...);
    
    return objc_msgSend(object, NSSelectorFromString(@"autorelease"));
}

///Releases a given object implementing the `<NSObject>` protocol.
///
///This function should be considered unsafe.
RK_INLINE void RKObjectRelease(id <NSObject> object)
{
    //So we don't have to include the objc runtime headers.
    extern id objc_msgSend(id, SEL, ...);
    
    ((void(*)(id, SEL))objc_msgSend)(object, NSSelectorFromString(@"release"));
}

#endif /* RKPrelude_h */
