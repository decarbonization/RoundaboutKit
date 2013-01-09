//
//  RKSongIdentifiers.h
//  Pinna
//
//  Created by Kevin MacWhinnie on 12/20/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#ifndef RKSongIdentifiers_h
#define RKSongIdentifiers_h 1

#import <Foundation/Foundation.h>
#import "RKPrelude.h"

///This function is deprecated and should not be used in new code.
///
///Returns a newly generated song ID for a specified name, artist,
///and album taken from a song.
///
///This function will always produce the same output given the same
///(or sufficiently similar) input. The output of this function is
///intended to provide a unique key.
///
///At least one of the parameters of this function must be non-nil.
///If any parameter is omitted, the resulting ID is marked as broken.
DEPRECATED_ATTRIBUTE RK_EXTERN NSString *RKGenerateSongID(NSString *name, NSString *artist, NSString *album);

#endif /* RKSongIdentifiers_h */
