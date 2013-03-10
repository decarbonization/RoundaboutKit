//
//  RKAwait.h
//  LiveNationApp
//
//  Created by Kevin MacWhinnie on 3/8/13.
//  Copyright (c) 2013 Live Nation Labs. All rights reserved.
//

#ifndef LiveNationApp_RKAwait_h
#define LiveNationApp_RKAwait_h

#import "RKPromise.h"

///Realizes a given promise object, blocking the caller's thread.
///
/// \param  promise     The promise to synchronously realize.
/// \param  outError    On return, pointer that contains an error object
///                     describing any issues. Parameter may be ommitted.
///
/// \result The result of realizing the promise.
///
///The two forms of RKAwait behave slightly differently. The form which includes
///an `outError` parameter will return nil when an error occurs. The form which
///does not include `outError` will raise an exception if an error occurs.
///In this form, if nil is returned it is the result of the promise.
RK_EXTERN_OVERLOADABLE id RKAwait(RKPromise *promise, NSError **outError);
RK_EXTERN_OVERLOADABLE id RKAwait(RKPromise *promise);

#endif
