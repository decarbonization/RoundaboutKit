//
//  RKBinding.h
//  Pinna
//
//  Created by Kevin MacWhinnie on 12/18/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

///The RKBinding object encapsulates a connection between the key path
///of a source object, and the key path of a destination object.
///
///Bindings are automatically disconnected when deallocated.
@interface RKBinding : NSObject

///Initialize the receiver with a specified target and key path.
///
/// \param  target  The object this binding will be to. Required.
/// \param  keyPath The key path of the object that will be bound to another object. Required.
///
/// \result A fully initialized RKBinding object.
///
- (id)initWithTarget:(__weak NSObject *)target keyPath:(NSString *)keyPath;

#pragma mark - Connections

///Whether or not the binding is connected.
@property (readonly) BOOL isConnected;

///Connects this binding to a specified key path in a specified object.
///
/// \param  object  The object to bind to. Required.
/// \param  keyPath The key path of the object to bind to. Required.
///
/// \result self
///
///This method throws an exception if the receiver is already connected.
- (RKBinding *)connectTo:(NSObject *)object keyPath:(NSString *)keyPath;

///Disconnects this binding.
///
/// \result self
///
///This method does nothing if the receiver isn't connected.
- (RKBinding *)disconnect;

@end

#pragma mark -

///The convenience methods for use with the RKBinding class.
@interface NSObject (RKBinding)

///Returns a new binding object for a specified key path that is not owned by the receiver.
///
///This method should be preferred if a binding has a lifecycle outside of the receiver's.
- (RKBinding *)untrackedBindingFor:(NSString *)keyPath;

///Returns a new binding object for a specified key path that is owned by the receiver.
///
///Bindings are tracked on a per-thread basis.
- (RKBinding *)bindingFor:(NSString *)keyPath;

#pragma mark - Tracking Bindings

///The bindings owned by the object.
///
///This property is thread-specific.
@property (readonly) NSMutableArray *bindings;

@end