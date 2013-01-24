//
//  RKPrelude.m
//  NewBrowser
//
//  Created by Kevin MacWhinnie on 2/8/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#import "RKPrelude.h"

#pragma mark Collection Operations

#pragma mark - • Generation

NSArray *RKCollectionGenerateArray(NSUInteger length, RKGeneratorBlock generator)
{
    NSCParameterAssert(generator);
    
    NSMutableArray *result = [NSMutableArray array];
    
    for (NSUInteger index = 0; index < length; index++) {
        id object = generator(index);
        if(object)
            [result addObject:object];
    }
    
    return result;
}

#pragma mark - • Mapping

NSArray *RKCollectionMapToArray(id input, RKMapperBlock mapper)
{
	return [RKCollectionMapToMutableArray(input, mapper) copyWithZone:[input zone]];
}

NSMutableArray *RKCollectionMapToMutableArray(id input, RKMapperBlock mapper)
{
    NSCParameterAssert(mapper);
	
	NSMutableArray *result = [NSMutableArray array];
	
	for (id object in input) {
		id mappedObject = mapper(object);
		if(mappedObject)
			[result addObject:mappedObject];
	}
	
	return result;
}

NSOrderedSet *RKCollectionMapToOrderedSet(id input, RKMapperBlock mapper)
{
	NSCParameterAssert(mapper);
	
	NSMutableOrderedSet *result = [NSMutableOrderedSet orderedSet];
	
	for (id object in input) {
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

#pragma mark - • Filtering

NSArray *RKCollectionFilterToArray(id input, RKPredicateBlock predicate)
{
	NSCParameterAssert(predicate);
	
	NSMutableArray *result = [NSMutableArray array];
	
	for (id object in input) {
		if(predicate(object))
			[result addObject:object];
	}
	
	return [result copyWithZone:[input zone]];
}

#pragma mark - • Matching

BOOL RKCollectionDoesAnyValueMatch(id input, RKPredicateBlock predicate)
{
	NSCParameterAssert(predicate);
	
	for (id object in input) {
		if(predicate(object))
			return YES;
	}
	
	return NO;
}

BOOL RKCollectionDoAllValuesMatch(id input, RKPredicateBlock predicate)
{
	NSCParameterAssert(predicate);
	
	for (id object in input) {
		if(!predicate(object))
			return NO;
	}
	
	return YES;
}

id RKCollectionFindFirstMatch(id input, RKPredicateBlock predicate)
{
	NSCParameterAssert(predicate);
	
	for (id object in input) {
		if(predicate(object))
			return object;
	}
	
	return nil;
}

#pragma mark - Time Intervals

NSTimeInterval const kRKTimeIntervalInfinite = INFINITY;

NSString *RKMakeStringFromTimeInterval(NSTimeInterval total)
{
	if(total < 0.0 || total == INFINITY)
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

#pragma mark - Utilities

NSString *RKSanitizeStringForSorting(NSString *string)
{
	if([string length] <= 4)
		return string;
	
	NSRange rangeOfThe = [string rangeOfString:@"the " options:(NSAnchoredSearch | NSCaseInsensitiveSearch) range:NSMakeRange(0, 4)];
	if(rangeOfThe.location != NSNotFound)
		return [string substringFromIndex:NSMaxRange(rangeOfThe)];
	
	return string;
}

NSString *RKGenerateIdentifierForStrings(NSArray *strings)
{
    NSCParameterAssert(strings);
    
    NSString *(^sanitize)(NSString *) = ^(NSString *string)
    {
        //An identifier cannot contain whitespace, punctuation, or symbols.
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
    };
    
    NSArray *sanitizedStrings = RKCollectionMapToArray(strings, ^(NSString *string) {
        return sanitize(string);
    });
    NSArray *sortedStrings = [sanitizedStrings sortedArrayUsingSelector:@selector(compare:)];
    return [sortedStrings componentsJoinedByString:@""];
}
