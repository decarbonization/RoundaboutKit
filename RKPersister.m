//
//  RKPersister.m
//  RoundaboutKit
//
//  Created by Kevin MacWhinnie on 10/11/13.
//  Copyright (c) 2013 Live Nation Labs. All rights reserved.
//

#import "RKPersister.h"

NSString *const RKPersisterDidLoadNotification = @"RKPersisterDidLoadNotification";
NSString *const RKPersisterDidSaveNotification = @"RKPersisterDidSaveNotification";
NSString *const RKPersisterDidFailToSaveNotification = @"RKPersisterDidFailToSaveNotification";
NSString *const RKPersisterDidUnloadNotification = @"RKPersisterDidUnloadNotification";


static NSString *const kLastModifiedKey = @"LastModified";
static NSString *const kContentsKey = @"Contents";

@interface RKPersister () {
    ///The dispatch queue that is used to synchronize reads and writes to the file system.
    dispatch_queue_t _fileSystemQueue;
}

///The in memory copy of the contents of the persister. Asynchronously populated.
@property id cachedContents;

///The current save handler block, if any.
@property (copy) RKPersisterSaveCompletionHandlerBlock currentSaveHandler;

///Whether or not the persister is waiting for its contents to persist.
///
///This property being set to YES will prevent `-[self unload]`
///from discarding the cached contents from memory.
@property BOOL waitingForContentsToPersist;

#pragma mark - readwrite

@property (nonatomic, readwrite) NSURL *location;
@property (nonatomic, readwrite) BOOL respondsToMemoryPressure;
@property (readwrite) NSDate *lastModified;

@end

#pragma mark -

@implementation RKPersister

+ (NSURL *)preferredLocationForPersistentContentsWithName:(NSString *)name fromBundle:(NSBundle *)bundle
{
    NSParameterAssert(name);
    
    if(!bundle)
        bundle = [NSBundle mainBundle];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSError *error = nil;
    NSURL *baseURL = [fileManager URLForDirectory:NSApplicationSupportDirectory
                                         inDomain:NSUserDomainMask
                                appropriateForURL:nil
                                           create:YES
                                            error:&error];
    if(!baseURL) {
        baseURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
        NSLog(@"*** Warning, could not find documents directory, using temporary directory. %@", error);
    }
    
    NSURL *bundleSupportURL = [baseURL URLByAppendingPathComponent:bundle.bundleIdentifier isDirectory:YES];
    if(![bundleSupportURL checkResourceIsReachableAndReturnError:NULL]) {
        if(![fileManager createDirectoryAtURL:bundleSupportURL withIntermediateDirectories:YES attributes:nil error:&error]) {
            bundleSupportURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
            NSLog(@"*** Warning, could not create bundle application support directory, using temporary directory. %@", error);
        }
    }
    
    NSURL *contentsLocation = [bundleSupportURL URLByAppendingPathComponent:name isDirectory:NO];
    return contentsLocation;
}

#pragma mark - Lifecycle

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if(_delegate) {
        [[NSNotificationCenter defaultCenter] removeObserver:_delegate name:RKPersisterDidLoadNotification object:self];
        [[NSNotificationCenter defaultCenter] removeObserver:_delegate name:RKPersisterDidSaveNotification object:self];
        [[NSNotificationCenter defaultCenter] removeObserver:_delegate name:RKPersisterDidFailToSaveNotification object:self];
        [[NSNotificationCenter defaultCenter] removeObserver:_delegate name:RKPersisterDidUnloadNotification object:self];
    }
}

- (instancetype)initWithLocation:(NSURL *)location loadImmediately:(BOOL)loadImmediately respondsToMemoryPressure:(BOOL)respondsToMemoryPressure
{
    NSParameterAssert(location);
    
    if(!location.isFileURL)
        [NSException raise:NSInvalidArgumentException format:@"location must be a file URL"];
    
    if((self = [super init])) {
        _fileSystemQueue = dispatch_queue_create("com.livenationlabs.RKPersister.fileSystemQueue", DISPATCH_QUEUE_SERIAL);
        
        self.location = location;
        
        self.respondsToMemoryPressure = respondsToMemoryPressure;
        if(respondsToMemoryPressure) {
#if TARGET_OS_IPHONE
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(applicationDidReceiveMemoryWarning:)
                                                         name:UIApplicationDidReceiveMemoryWarningNotification
                                                       object:nil];
#endif /* TARGET_OS_IPHONE */
        }
        
        if(loadImmediately)
            [self reloadContentsAsynchronously];
    }
    
    return self;
}

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma mark - Properties

- (void)setDelegate:(id<RKPersisterDelegate>)delegate
{
    if(_delegate) {
        [[NSNotificationCenter defaultCenter] removeObserver:_delegate name:RKPersisterDidLoadNotification object:self];
        [[NSNotificationCenter defaultCenter] removeObserver:_delegate name:RKPersisterDidSaveNotification object:self];
        [[NSNotificationCenter defaultCenter] removeObserver:_delegate name:RKPersisterDidFailToSaveNotification object:self];
        [[NSNotificationCenter defaultCenter] removeObserver:_delegate name:RKPersisterDidUnloadNotification object:self];
    }
    
    _delegate = delegate;
    
    if(_delegate) {
        [[NSNotificationCenter defaultCenter] addObserver:_delegate selector:@selector(persisterDidLoad:) name:RKPersisterDidLoadNotification object:self];
        [[NSNotificationCenter defaultCenter] addObserver:_delegate selector:@selector(persisterDidSave:) name:RKPersisterDidSaveNotification object:self];
        [[NSNotificationCenter defaultCenter] addObserver:_delegate selector:@selector(persisterDidFailToSave:) name:RKPersisterDidFailToSaveNotification object:self];
        [[NSNotificationCenter defaultCenter] addObserver:_delegate selector:@selector(persisterDidUnload:) name:RKPersisterDidUnloadNotification object:self];
    }
}

#pragma mark - Notifications

- (void)applicationDidReceiveMemoryWarning:(NSNotification *)notification
{
    [self unload];
}

#pragma mark - Contents

- (void)setContents:(NSObject <NSCoding> *)contents saveCompletionHandler:(RKPersisterSaveCompletionHandlerBlock)saveHandler
{
    self.waitingForContentsToPersist = YES;
    self.cachedContents = contents;
    self.currentSaveHandler = saveHandler;
    
    [self saveContentsAsynchronously];
}

- (id)contents
{
    return self.cachedContents;
}

#pragma mark - Reading/Writing

- (BOOL)remove:(NSError **)outError
{
    __block NSError *error = nil;
    __block BOOL success = NO;
    dispatch_sync(_fileSystemQueue, ^{
        success = [[NSFileManager defaultManager] removeItemAtURL:self.location error:&error];
    });
    
    if(success) {
        [self willChangeValueForKey:@"contents"];
        self.cachedContents = nil;
        [self didChangeValueForKey:@"contents"];
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:RKPersisterDidFailToSaveNotification
                                                            object:self
                                                          userInfo:@{NSUnderlyingErrorKey: error}];
    }
    
    if(outError && error) *outError = error;
    
    return success;
}

- (void)reloadContentsAsynchronously
{
    dispatch_async(_fileSystemQueue, ^{
        NSError *error = nil;
        NSData *rawContents = [NSData dataWithContentsOfURL:self.location options:kNilOptions error:&error];
        
        NSDictionary *persistedInfo = nil;
        if(rawContents)
            persistedInfo = [NSKeyedUnarchiver unarchiveObjectWithData:rawContents];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.lastModified = persistedInfo[kLastModifiedKey];
            
            [self willChangeValueForKey:@"contents"];
            self.cachedContents = persistedInfo[kContentsKey];
            [self didChangeValueForKey:@"contents"];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:RKPersisterDidLoadNotification
                                                                object:self];
        });
    });
}

- (BOOL)unload
{
    if(!self.waitingForContentsToPersist) {
        [self willChangeValueForKey:@"contents"];
        self.cachedContents = nil;
        [self didChangeValueForKey:@"contents"];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:RKPersisterDidUnloadNotification
                                                            object:self];
        
        return YES;
    } else {
        return NO;
    }
}

- (void)saveContentsAsynchronously
{
    dispatch_async(_fileSystemQueue, ^{
#if TARGET_OS_IPHONE
        UIBackgroundTaskIdentifier taskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
#endif /* TARGET_OS_IPHONE */
        
        NSDictionary *infoToPersist;
        if(self.cachedContents)
            infoToPersist = @{ kLastModifiedKey: [NSDate date],
                               kContentsKey: self.cachedContents };
        else
            infoToPersist = @{ kLastModifiedKey: [NSDate date] };
        
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:infoToPersist];
        
        NSError *error = nil;
        BOOL success = [data writeToURL:self.location options:NSDataWritingAtomic error:&error];
        
        self.waitingForContentsToPersist = NO;
        
        if(success)
            self.lastModified = infoToPersist[kLastModifiedKey];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(self.currentSaveHandler)
                self.currentSaveHandler(success, error);
            
            self.currentSaveHandler = nil;
            
            if(success)
                [[NSNotificationCenter defaultCenter] postNotificationName:RKPersisterDidSaveNotification
                                                                    object:self];
            else
                [[NSNotificationCenter defaultCenter] postNotificationName:RKPersisterDidFailToSaveNotification
                                                                    object:self
                                                                  userInfo:@{NSUnderlyingErrorKey: error}];
        });
        
#if TARGET_OS_IPHONE
        if(taskIdentifier != UIBackgroundTaskInvalid)
            [[UIApplication sharedApplication] endBackgroundTask:taskIdentifier];
#endif /* TARGET_OS_IPHONE */
    });
}

@end
