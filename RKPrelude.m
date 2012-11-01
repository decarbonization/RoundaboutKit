//
//  RKPrelude.m
//  NewBrowser
//
//  Created by Kevin MacWhinnie on 2/8/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RKPrelude.h"

#pragma mark Collection Operations

#pragma mark • Mapping

NSArray *RKCollectionMapToArray(id input, RKMapperBlock mapper)
{
	NSCParameterAssert(mapper);
	
	NSMutableArray *result = [NSMutableArray array];
	
	for (id object in input)
	{
		id mappedObject = mapper(object);
		if(mappedObject)
			[result addObject:mappedObject];
	}
	
	return [result copyWithZone:[input zone]];
}

NSOrderedSet *RKCollectionMapToOrderedSet(id input, RKMapperBlock mapper)
{
	NSCParameterAssert(mapper);
	
	NSMutableOrderedSet *result = [NSMutableOrderedSet orderedSet];
	
	for (id object in input)
	{
		id mappedObject = mapper(object);
		if(mappedObject)
			[result addObject:mappedObject];
	}
	
	return [result copyWithZone:[input zone]];
}

NSDictionary *RKDictionaryMap(NSDictionary *input, RKMapperBlock mapper)
{
	NSCParameterAssert(mapper);
	
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	[input enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
		id mappedObject = mapper(object);
		if(mappedObject)
			[result setObject:mappedObject forKey:key];
	}];
	
	return [result copy];
}

#pragma mark -
#pragma mark • Filtering

NSArray *RKCollectionFilterToArray(id input, RKPredicateBlock predicate)
{
	NSCParameterAssert(predicate);
	
	NSMutableArray *result = [NSMutableArray array];
	
	for (id object in input)
	{
		if(predicate(object))
			[result addObject:object];
	}
	
	return [result copyWithZone:[input zone]];
}

#pragma mark -
#pragma mark • Matching

BOOL RKCollectionDoesAnyValueMatch(id input, RKPredicateBlock predicate)
{
	NSCParameterAssert(predicate);
	
	for (id object in input)
	{
		if(predicate(object))
			return YES;
	}
	
	return NO;
}

BOOL RKCollectionDoAllValuesMatch(id input, RKPredicateBlock predicate)
{
	NSCParameterAssert(predicate);
	
	for (id object in input)
	{
		if(!predicate(object))
			return NO;
	}
	
	return YES;
}

id RKCollectionFindFirstMatch(id input, RKPredicateBlock predicate)
{
	NSCParameterAssert(predicate);
	
	for (id object in input)
	{
		if(predicate(object))
			return object;
	}
	
	return nil;
}

#pragma mark -
#pragma mark Time Intervals

NSTimeInterval const kRKTimeUnavailable = (-DBL_MAX);

NSString *RKMakeStringFromTimeInterval(NSTimeInterval total)
{
	if(total < 0.0)
		return @"-:--";
	
	long long roundedTotal = (long long)round(total);
	NSInteger hours = (roundedTotal / (60 * 60)) % 24;
	NSInteger minutes = (roundedTotal / 60) % 60;
	NSInteger seconds = roundedTotal % 60;
#if __LP64__
	if(hours > 0)
		return [NSString localizedStringWithFormat:@"%ld:%02ld:%02ld", hours, minutes, seconds];
	
	return [NSString localizedStringWithFormat:@"%ld:%02ld", minutes, seconds];
#else
	if(hours > 0)
		return [NSString localizedStringWithFormat:@"%d:%02d:%02d", hours, minutes, seconds];
	
	return [NSString localizedStringWithFormat:@"%d:%02d", minutes, seconds];
#endif
}

#pragma mark -
#pragma mark Utilities

NSString *RKSanitizeStringForSorting(NSString *string)
{
	if([string length] <= 4)
		return string;
	
	NSRange rangeOfThe = [string rangeOfString:@"the " options:(NSAnchoredSearch | NSCaseInsensitiveSearch) range:NSMakeRange(0, 4)];
	if(rangeOfThe.location != NSNotFound)
		return [string substringFromIndex:NSMaxRange(rangeOfThe)];
	
	return string;
}

#pragma mark -

void RKEnumerateFilesInLocation(NSURL *folderLocation, void(^callback)(NSURL *location))
{
	NSCParameterAssert(folderLocation);
	NSCAssert([folderLocation isFileURL], @"Cannot find files in the cloud, you idiot.");
	
	NSNumber *isDirectory = nil;
	if(![folderLocation getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil])
		NSCAssert(0, @"Couldn't retrieve NSURLIsDirectoryKey for %@", folderLocation);
	
	if(![isDirectory boolValue])
	{
		callback(folderLocation);
		return;
	}
	
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:folderLocation 
															 includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLIsDirectoryKey, NSURLTypeIdentifierKey, nil] 
																				options:NSDirectoryEnumerationSkipsHiddenFiles 
																		   errorHandler:^(NSURL *url, NSError *error) {
																			   NSLog(@"%@ for %@", [error localizedDescription], url);
																			   return NO;
																		   }];
	
	for (NSURL *item in enumerator)
	{
		if(![item getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil])
			NSCAssert(0, @"Couldn't retrieve NSURLIsDirectoryKey for %@", item);
		
		NSString *type = nil;
		if(![item getResourceValue:&type forKey:NSURLTypeIdentifierKey error:nil])
			NSCAssert(0, @"Couldn't retrieve NSURLTypeIdentifierKey for %@", item);
		
		if([isDirectory boolValue] || [type rangeOfString:@"audio"].location == NSNotFound)
			continue;
		
		callback(item);
	}
}

#pragma mark -
#pragma mark Song IDs

static NSString *RemoveBlacklistedCharactersForSongID(NSString *string)
{
	//A song ID cannot contain whitespace, punctuation, or symbols.
	//We create an all encompassing character set to test for these.
	static NSMutableCharacterSet *charactersToRemove = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		charactersToRemove = [NSMutableCharacterSet new];
		[charactersToRemove formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		[charactersToRemove formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
		[charactersToRemove formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
	});
	
	NSMutableString *resultString = [[string lowercaseString] mutableCopy];
	for (NSUInteger index = 0; index < [resultString length]; index++)
	{
		unichar character = [resultString characterAtIndex:index];
		if([charactersToRemove characterIsMember:character])
		{
			[resultString deleteCharactersInRange:NSMakeRange(index, 1)];
			index--;
		}
	}
	
	return resultString;
}

NSString *RKGenerateSongID(NSString *name, NSString *artist, NSString *album)
{
	//We require at least one parameter to
	//generate a song ID. All must be specified
	//in order for the ID to be non-broken.
	if(!name && !artist && !album)
	{
		[NSException raise:NSInvalidArgumentException 
					format:@"RKGenerateSongID called with only nil parameters"];
	}
	
	NSMutableArray *components = [NSMutableArray array];
	
	if(name)
		[components addObject:name];
	
	if(artist)
		[components addObject:artist];
	
	if(album)
		[components addObject:album];
	
	[components sortUsingSelector:@selector(compare:)];
	
	NSString *componentsCompound = RemoveBlacklistedCharactersForSongID([components componentsJoinedByString:@""]);
	NSString *marker = (!name || !artist || !album)? @"IN" : @"CO";
	
	return [NSString stringWithFormat:@"X-ROUNDABOUT-SID-3^%@-%@", componentsCompound, marker];
}
