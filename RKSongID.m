//
//  RKSongIdentifiers.m
//  Pinna
//
//  Created by Kevin MacWhinnie on 12/20/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#import "RKSongID.h"

void RKGenerateSongIDEmitDeprecatedWarning()
{
#if RoundaboutKit_EmitWarnings
    NSLog(@"*** Warning, RKGenerateSongID is deprecated. Add a breakpoint to RKGenerateSongIDEmitDeprecatedWarning to debug.");
#endif /* RoundaboutKit_EmitWarnings */
}

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
    RKGenerateSongIDEmitDeprecatedWarning();
    
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
