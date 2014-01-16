//
//  RKParameters.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/19/13.
//  Copyright (c) 2013 Roundabout Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

///The different ways to handle null values passed into RKRequestParameters.
typedef NS_ENUM(NSInteger, RKRequestParametersNilHandlingMode) {
    ///Raise an exception for any nil values.
    RKRequestParametersNilHandlingModeThrow = 0,
    
    ///Silently ignore any nil values.
    RKRequestParametersNilHandlingModeIgnore,
    
    ///Substitute an empty string for any nil values.
    RKRequestParametersNilHandlingModeSubstituteEmptyString,
    
    ///Substitute NSNull for any nil values.
    RKRequestParametersNilHandlingModeSubstituteNSNull,
};


///The RKRequestParameters class is an abstraction on top of NSDictionary that provides
///a degree of safety around constructing parameters for networking requests.
@interface RKRequestParameters : NSObject

///Initialize the receiver with the preferred nil handling mode.
///
/// \param  mode    What should be done when given nil values.
///
/// \result A fully initialized request parameters object.
///
///This is the designated initializer.
- (instancetype)initWithNilHandlingMode:(RKRequestParametersNilHandlingMode)mode;

///Unavailable. Use `-[self initWithNilHandlingMode:]`
- (id)init UNAVAILABLE_ATTRIBUTE;

#pragma mark - Properties

///How the request parameters instance handles nil values.
@property (nonatomic, readonly) RKRequestParametersNilHandlingMode nilHandlingMode;

#pragma mark - Getting and Setting Parameters

///Sets the object associated with a given key.
///
/// \param  object  The object to associated with the key. How nil
///                 values are handled by this parameter is specified
///                 by the receiver's `self.nilHandlingMode` value.
/// \param  key     The key. Must not be nil.
///
- (void)setObject:(id)object forKey:(NSString *)key;

///Returns the object associated with a given key, if any.
///
/// \param  key The Key. Must not be nil.
///
/// \result The object associated with the key, or nil if there was none.
///
- (id)objectForKey:(NSString *)key;

#pragma mark - Conversions

///Returns a dictionary representation of the parameters contained in the receiver.
- (NSDictionary *)dictionaryRepresentation;

#pragma mark - Subscripting Support

- (id)objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(id)obj forKeyedSubscript:(NSString *)key;

#pragma mark - KVC Support

- (void)setValue:(id)value forUndefinedKey:(NSString *)key;
- (id)valueForUndefinedKey:(NSString *)key;

@end
