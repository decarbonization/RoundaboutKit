//
//  RKBinding.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/18/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#ifndef RKBinding_h
#define RKBinding_h 1

#import <Foundation/Foundation.h>
#import "RKPromise.h"

///The different types of binding connections.
typedef enum RKBindingConnectionType {
    
    ///The default binding connection type.
    kRKBindingConnectionTypeOneWayBinding = 0,
    
} RKBindingConnectionType;

///The RKBinding object encapsulates a connection between the key path
///of a source object, and the key path of a destination object.
///
///The lifecycle of bindings is controlled by the binding mechanism.
///No external references should be kept to binding objects, as this
///can lead to dangling pointers due to RKBinding using unsafe_unretained
///variables to track connected-to objects due to technical limitations
///of the current __weak variable implementation.
///
///It is not safe to access the binding mechanism from multiple threads,
///and as with the built-in AppKit binding mechanism, it is undefined
///behaviour to emit change notifications from background threads.
///
/// \seealso(-[NSObject(RKBinding) bindingFor:])
@interface RKBinding : NSObject

#pragma mark - Connections

///Whether or not the binding is connected.
@property (readonly, RK_NONATOMIC_IOSONLY) BOOL isConnected;

///Connects this binding to a specified key path in a specified object.
///
/// \param  object  The object to bind to. Non-retained. Required.
/// \param  keyPath The key path of the object to bind to. Required.
///
/// \result self
///
///If the receiver is already connected, it will be disconnected,
///and then connected to the new object-keypath.
- (RKBinding *)connectTo:(NSObject *)object keyPath:(NSString *)keyPath;

///Disconnects this binding.
///
/// \result self
///
///This method does nothing if the receiver isn't connected.
- (RKBinding *)disconnect;

#pragma mark -

///The connection type of the binding.
@property (readonly, RK_NONATOMIC_IOSONLY) RKBindingConnectionType connectionType;

#pragma mark - Options

///The value to substitute when the key path on the connected-to-object yields nil.
@property (RK_NONATOMIC_IOSONLY) id defaultValue;

///The value transformer to use.
@property (RK_NONATOMIC_IOSONLY) NSValueTransformer *valueTransformer;

#pragma mark - Promise Support

///Whether or not promises should be realized.
///
///Default value is YES.
///
///When a promise is encountered by a binding, the default value is set
///on the target object while the promise is realized.
///
///Multi-part promises will result in the target's value-keypath being
///updated multiple times (once for each part).
@property (RK_NONATOMIC_IOSONLY) BOOL realizePromises;

///The block to invoke when realizing a promise fails.
@property (copy) RKPromiseFailureBlock promiseFailureBlock;

@end

#pragma mark -

///The methods added to the NSObject class to enable
///the RKBinding mechanism to be fully functional.
///
///Including this category in your project will change
///the default implementation of `-dealloc` to enable
///the automatic disconnection mechanism of RKBinding.
@interface NSObject (RKBinding)

///Returns a binding object for the receiver for a given key path,
///creating the binding object if it does not exist.
///
///The returned binding will be disconnected and deallocated when
///the receiver or the object eventually connected to are released.
///
///This method is not threadsafe.
- (RKBinding *)bindingFor:(NSString *)keyPath;

@end

#pragma mark -

///The methods added to the NSArray class to enable
///the RKBinding mechanism to be fully functional.
@interface NSArray (RKBinding)

///Returns an array of new binding objects for a specified key path that are owned by the objects in the array.
- (NSArray *)bindingsFor:(NSString *)keyPath;

@end

#pragma mark - One-Off Observations

///Creates and returns a one-time key-value change observer object.
///
/// \param  target      The object to observe for changes. Required.
/// \param  keyPath     The key path to observe for changes on `target`. Required.
/// \param  callback    The block to invoke when the change happens. Required.
///
/// \result An opaque object responsible for propagating changes from `target.keyPath` to `callback`.
RK_EXTERN_OVERLOADABLE id RKObserveOnce(id target, NSString *keyPath, void(^callback)(id value));

#endif /* RKBinding_h */
