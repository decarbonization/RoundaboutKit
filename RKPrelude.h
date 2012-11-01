//
//  RKPrelude.h
//  NewBrowser
//
//  Created by Kevin MacWhinnie on 2/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#ifndef RKPrelude_h
#define RKPrelude_h 1

#import <Foundation/Foundation.h>

#pragma mark Goop

#if __cplusplus
#	define RK_EXTERN extern "C"
#	define RK_OVERLOADABLE	
#else
#	define RK_EXTERN extern
#	define RK_OVERLOADABLE	__attribute__((overloadable))
#endif /* __cplusplus */

#define RK_INLINE static inline

///Whether or not a flag is set on a bitfield.
///	\param	field	The field to check for the flag on.
///	\param	flag	The flag.
#define RK_FLAG_IS_SET(field, flag) ((flag & field) == flag)

#pragma mark -
#pragma mark Time Constants

///The number of seconds in a minute.
#define RK_TIME_MINUTE	(60.0)

///The number of seconds in an hour.
#define RK_TIME_HOUR	(RK_TIME_MINUTE * 60.0)

///The number of seconds in a day.
#define RK_TIME_DAY		(RK_TIME_HOUR * 24.0)

///The number of seconds in a week.
#define RK_TIME_WEEK	(RK_TIME_DAY * 7.0)

#pragma mark -
#pragma mark Collection Shorthand

#define NSARRAY(...) [NSArray arrayWithObjects:__VA_ARGS__, nil]
#define NSSET(...) [NSSet setWithObjects:__VA_ARGS__, nil]
#define NSDICT(...) [NSDictionary dictionaryWithObjectsAndKeys:__VA_ARGS__, nil]

#pragma mark -
#pragma mark Collection Operations

///A Predicate is a block that takes an object and applies a test to it, returning the result.
typedef BOOL(^RKPredicateBlock)(id value);

///A Mapper is a block that takes an object and performs an operation on it, returning the result.
typedef id(^RKMapperBlock)(id value);

#pragma mark -
#pragma mark • Mapping

///Returns a collection mapped to an array.
RK_EXTERN NSArray *RKCollectionMapToArray(id input, RKMapperBlock mapper);

///Returns a collection mapped to an ordered set.
RK_EXTERN NSOrderedSet *RKCollectionMapToOrderedSet(id input, RKMapperBlock mapper);

///Returns a dictionary mapped.
RK_EXTERN NSDictionary *RKDictionaryMap(NSDictionary *input, RKMapperBlock mapper);

#pragma mark -
#pragma mark • Filtering

///Returns a given collection filtered into an array.
RK_EXTERN NSArray *RKCollectionFilterToArray(id input, RKPredicateBlock predicate);

#pragma mark -
#pragma mark • Matching

///Returns YES if any value in a given collection passes a specified predicate; NO otherwise.
RK_EXTERN BOOL RKCollectionDoesAnyValueMatch(id input, RKPredicateBlock predicate);

///Returns YES if all values in a given collection pass a specified predicate; NO otherwise.
RK_EXTERN BOOL RKCollectionDoAllValuesMatch(id input, RKPredicateBlock predicate);

///Returns the first object matching a given predicate in a given collection.
RK_EXTERN id RKCollectionFindFirstMatch(id input, RKPredicateBlock predicate);

#pragma mark -
#pragma mark Time Intervals

///Returns a human readable time stamp for a given time interval.
///
///If the time interval is negative, this function returns `@"Continuous"`.
RK_EXTERN NSString *RKMakeStringFromTimeInterval(NSTimeInterval total);

#pragma mark -
#pragma mark Utilities

///Returns an NSString sans 'the' at the beginning.
RK_EXTERN NSString *RKSanitizeStringForSorting(NSString *string);

///Generates a unique identifier through CFUUID.
RK_INLINE NSString *RKMakeUUIDString()
{
#if __has_feature(objc_arc)
	CFUUIDRef uniqueIdentifier = CFUUIDCreate(kCFAllocatorDefault);
	NSString *uniqueIdentifierString = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uniqueIdentifier);
	CFRelease(uniqueIdentifier);
	return uniqueIdentifierString;
#else
	CFStringRef uuid = CFUUIDCreateString(kCFAllocatorDefault, 
										  (CFUUIDRef)NSMakeCollectable(CFUUIDCreate(kCFAllocatorDefault)));
	return [NSString stringWithString:NSMakeCollectable(uuid)];
#endif
}

///Returns `nil` if `value` is NSNull, `value` otherwise.
RK_INLINE id RKFilterOutNSNull(id value)
{
	if(value == [NSNull null])
		return nil;
	
	return value;
}

#pragma mark -

///Enumerates all of the files in a given directory location.
RK_EXTERN void RKEnumerateFilesInLocation(NSURL *folderLocation, void(^callback)(NSURL *location));

#pragma mark -
#pragma mark Song IDs

///Returns a newly generated song ID for a specified name, artist,
///and album taken from a song.
///
///This function will always produce the same output given the same
///(or sufficiently similar) input. The output of this function is
///intended to provide a unique key.
///
///At least one of the parameters of this function must be non-nil.
///If any parameter is omitted, the resulting ID is marked as broken.
RK_EXTERN NSString *RKGenerateSongID(NSString *name, NSString *artist, NSString *album);

#endif /* RKPrelude_h */
