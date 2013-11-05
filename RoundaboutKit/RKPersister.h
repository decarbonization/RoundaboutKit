//
//  RKPersister.h
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 10/11/13.
//  Copyright (c) 2013 Live Nation Labs. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RKPersisterDelegate;


///The name of the notification posted when an RKPersister instance loads its contents.
///
///The object of the notification is the posting persister instance. There is no user info.
RK_EXTERN NSString *const RKPersisterDidLoadNotification;

///The name of the notification posted when an RKPersister instance saves its contents.
///
///The object of the notification is the posting persister instance. There is no user info.
RK_EXTERN NSString *const RKPersisterDidSaveNotification;

///The name of the notification posted when an RKPersister instance fails to save its contents.
///
///The object of the notification is the posting persister instance. The user info dictionary
///contains one key, NSUnderlyingErrorKey, which contains the save failure error.
RK_EXTERN NSString *const RKPersisterDidFailToSaveNotification;

///The name of the notification posted when an RKPersister instance unloads its contents.
///
///The object of the notification is the posting persister instance. There is no user info.
RK_EXTERN NSString *const RKPersisterDidUnloadNotification;


///A completion handler block used by RKPersister to notify observers of save operation completion.
///
/// \param  success Whether or not setting the contents was successful.
/// \param  error   An error describing any issues that occurred. nil unless success is YES.
///
///Completion handler blocks are always invoked on the main thread.
typedef void(^RKPersisterSaveCompletionHandlerBlock)(BOOL success, NSError *error);


///The RKPersister class encapsulates a simple asynchronous NSCoding-based object
///persistence mechanism suitable for use with small to medium sized payloads.
///
///RKPersister uses a serial dispatch queue internally to coordinate file system reads and writes.
@interface RKPersister : NSObject

///Returns RKPersister's recommended location for persistent contents with a given name.
///
/// \param  name    The name of the contents. Required.
/// \param  bundle  The bundle that owns the contents. Its identifier is used to determine
///                 the optimal location for the persistent contents. If nil,
///                 `+[NSBundle mainBundle]` will be substituted.
///
/// \result The recommended location.
///
///Any valid file URL may be given to RKPersister, this method is provided as a convenience.
+ (NSURL *)preferredLocationForPersistentContentsWithName:(NSString *)name fromBundle:(NSBundle *)bundle;

///Initialize the receiver with a given URL.
///
/// \param  location                    The URL the persister will read and write its contents from. Required.
/// \param  loadImmediately             Whether or not the contents of the persister should immediately be
///                                     asynchronously loaded.
/// \param  respondsToMemoryPressure    Whether or not the persister should release its contents when memory
///                                     pressure builds up in the host application.
///
/// \result A fully initialized persister, ready for use.
///
///This is the designated initializer.
- (instancetype)initWithLocation:(NSURL *)location loadImmediately:(BOOL)loadImmediately respondsToMemoryPressure:(BOOL)respondsToMemoryPressure;

#pragma mark - Properties

///The delegate of the persister.
@property (nonatomic, assign) id <RKPersisterDelegate> delegate;

///The location of the persisters file system store.
@property (nonatomic, readonly) NSURL *location;

///Whether or not the persister should respond to memory pressure.
@property (nonatomic, readonly) BOOL respondsToMemoryPressure;

#pragma mark -

///When the contents of the persister were last modified, nil if the contents have never been saved.
///
///This property is updated in a background thread when both `-[self load]`,
///and `-[self save]` are called. KVC observers should be used with care.
@property (readonly) NSDate *lastModified;

#pragma mark - Contents

///Sets the contents of the persister, saving them in the background,
///invoking an optional completion handler when the save is complete.
///
/// \param  contents    The value to save into the persister. May be nil.
/// \param  saveHandler The block to invoke when the save operation is completed. May be nil.
///
///The `-[RKPersister contents]` method will immediately reflect the value given to this method,
///but the persistence of the value will not be done until the `saveHandler` is invoked.
///
///Calling this method multiple times in a row will result in only the final save handler being invoked.
- (void)setContents:(NSObject <NSCoding> *)contents saveCompletionHandler:(RKPersisterSaveCompletionHandlerBlock)saveHandler;

///Returns the contents of the persister, if any.
///
///This method's return value does not match `-[self setContents:saveCompletionHandler:]`
///so that consumers of this value may implicitly cast it to whatever value they are expecting.
///
///This method may be safely observed through KVC.
- (id)contents;

#pragma mark - Reading/Writing

///Synchronously removes the contents of the persister from the file system.
///
///This method is synchronous under the assumption that it will be called from
///reset methods that are expected to return after their work is completed.
///
///This method has the side effect of clearing `-[self contents]`.
- (BOOL)remove:(NSError **)outError;

///Asynchronously loads the contents of the persister from the file system.
- (void)reloadContentsAsynchronously;

///Unloads the contents of the persister from memory
///if the file system copy of them is up to date.
///
/// \result YES if the file system copy was up to date and the contents could be unloaded; NO otherwise.
///
///This method is called in response to memory pressure.
- (BOOL)unload;

///Asynchronously saves the contents of the persister from the file system.
- (void)saveContentsAsynchronously;

@end

#pragma mark -

///The RKPersisterDelegate protocol describes the methods necessary for
///an object to act as the delegate of an RKPersister instance.
@protocol RKPersisterDelegate <NSObject>

///Informs the delegate that the persister has loaded its contents.
///
/// \seealso(RKPersisterDidLoadNotification)
- (void)persisterDidLoad:(NSNotification *)notification;

///Informs the delegate that the persister has saved its contents.
///
/// \seealso(RKPersisterDidSaveNotification)
- (void)persisterDidSave:(NSNotification *)notification;

///Informs the delegate that the persister has failed to save its contents.
///
/// \seealso(RKPersisterDidFailToSaveNotification)
- (void)persisterDidFailToSave:(NSNotification *)notification;

///Informs the delegate that the persister has unloaded its contents from memory.
///
/// \seealso(RKPersisterDidUnloadNotification)
- (void)persisterDidUnload:(NSNotification *)notification;

@end
