//
//  RKDefaults.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 6/6/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RKDefaults.h"

#pragma mark Defaults Short-hand

id RKSetPersistentObject(NSString *key, id object)
{
	NSCParameterAssert(key);
	[[NSUserDefaults standardUserDefaults] setObject:object forKey:key];
	return object;
}

id RKGetPersistentObject(NSString *key)
{
	NSCParameterAssert(key);
	return [[NSUserDefaults standardUserDefaults] objectForKey:key];
}

#pragma mark -

NSInteger RKSetPersistentInteger(NSString *key, NSInteger value)
{
	NSCParameterAssert(key);
	[[NSUserDefaults standardUserDefaults] setInteger:value forKey:key];
	return value;
}

NSInteger RKGetPersistentInteger(NSString *key)
{
	NSCParameterAssert(key);
	return [[NSUserDefaults standardUserDefaults] integerForKey:key];
}

#pragma mark -

float RKSetPersistentFloat(NSString *key, float value)
{
	NSCParameterAssert(key);
	[[NSUserDefaults standardUserDefaults] setFloat:value forKey:key];
	return value;
}

float RKGetPersistentFloat(NSString *key)
{
	NSCParameterAssert(key);
	return [[NSUserDefaults standardUserDefaults] floatForKey:key];
}

#pragma mark -

BOOL RKSetPersistentBool(NSString *key, BOOL value)
{
	NSCParameterAssert(key);
	[[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
	return value;
}

BOOL RKGetPersistentBool(NSString *key)
{
	NSCParameterAssert(key);
	return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

#pragma mark -

BOOL RKPersistentValueExists(NSString *key)
{
	NSCParameterAssert(key);
	return ([[NSUserDefaults standardUserDefaults] objectForKey:key] != nil);
}
