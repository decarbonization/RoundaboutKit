//
//  RKBinding.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 12/18/12.
//  Copyright (c) 2012 Roundabout Software, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RKPromise.h"

///The different types of binding connections.
typedef enum RKBindingConnectionType {
    
    ///The default binding connection type.
    kRKBindingConnectionTypeOneWayBinding = 0,
    
    ///The observation propagation connection type.
    kRKBindingConnectionTypeChangePropagation = 1,
    
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
///This method emits a warning if the receiver is already connected.
///This may be a hard error in the future.
- (RKBinding *)connectTo:(NSObject *)object keyPath:(NSString *)keyPath;

///Creates an observation connection wherein the target key path of the binding has
///change notifications propagated to it based on the connected-to object's key path.
///
/// \param  object  The object to quasi bind to. Non-retained. Requried.
/// \param  keyPath The key path of the object to quasi-bind to. Required.
///
/// \result self
///
///This method emits a warning if the receiver is already connected.
///This may be a hard error in the future.
- (RKBinding *)becomeAffectedBy:(NSObject *)object keyPath:(NSString *)keyPath;

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
