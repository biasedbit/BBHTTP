//
// Copyright 2013 BiasedBit
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

//
//  Created by Bruno de Carvalho - @biasedbit / http://biasedbit.com
//  Copyright (c) 2013 BiasedBit. All rights reserved.
//

@class BBHTTPRequest;
@class BBHTTPResponse;



#pragma mark -

/**
 The `BBHTTPExecutor` class is a request executor and queue manager that takes `<BBHTTPRequest>` instances and translates
 them for execution on the underlying libcurl infrastructure.
 
 It can be seen as a `NSOperationQueue` on which you enqueue operations &mdash; or, in this case, http requests.
 
 Given that each executor instance has little configuration and that configuration can safely be changed, using the 
 [singleton](<sharedExecutor>) is perfectly reasonable &mdash; encouraged, even.

 ### Request queuing and execution

 Whenever you submit a request, it will either be immediately executed or queued, depending on the number of active
 requests at the instant of submission.

 Submitted requests are strongly held (retain semantics) until their execution is terminated &mdash; either normally or
 abnormally &mdash; and the appropriate delegate blocks are called.

 At any time you may cancel a request. A queued request that is cancelled while still in the queue will remain in the 
 queue (with the `cancel` flag set to `YES`) until it is extracted for execution, at which point it is simply discarded.
 Assuming no other strong references to the request are kept, it will be `dealloc`'d at this time.

 ### libcurl handle pooling

 Each instance will create up to `<maxParallelRequests>` libcurl handles to execute requests, depending on number of
 parallel requests that may need to be performed. In other words, if you set the limit of libcurl handles to 3 but
 never execute more than one request at a time, the instance will only create and maintain a single handle.
 
 When all the handles are in use, request will be queued and executed later in time, in the first handle that frees up.
 
 ### libcurl handle setup
 
 Every time a request is executed, the handle is completely reconfigured and, upon termination, reset. This means that
 you can safely perform all sorts of requests to different hosts under the same `BBHTTPExecutor` instance.
 */
@interface BBHTTPExecutor : NSObject


#pragma mark Creating an instance

///---------------------------
/// @name Creating an instance
///---------------------------

/**
 Creates a new instace with the given unique identifier.
 
 @param identifier Unique identifier.
 
 @return An initialized `BBHTTPExecutor` with a unique *identifier*.
 */
- (instancetype)initWithId:(NSString*)identifier;

/**
 Returns a singleton `BBHTTPExecutor`
 
 @return A `BBHTTPExecutor` singleton.
 */
+ (instancetype)sharedExecutor;


#pragma mark Configuring behavior

///---------------------------
/// @name Configuring behavior
///---------------------------

/**
 Determines the maximum number of maximum parallel requests that can be executed.
 
 This value controls the number of libcurl handles that this instance can pool. All instances begin with zero handles 
 and ramp them up, as required, until this number is hit.
 
 Defaults to 3, minimum allowed value is 1.
 */
@property(assign, nonatomic) NSUInteger maxParallelRequests;

/**
 The maximum number of requests that can be queued until others finish.
 
 Defaults to 1024.
 */
@property(assign, nonatomic) NSUInteger maxQueueSize;

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
@property(assign, nonatomic) BOOL manageNetworkActivityIndicator;
#endif

/** For debug/bug-reporting purposes only; this turns on verbose mode for the underlying libcurl handles. */
@property(assign, nonatomic) BOOL verbose;
/** Opens and closes a connection for each request. */
@property(assign, nonatomic) BOOL dontReuseConnections;


#pragma mark Executing requests

///-------------------------
/// @name Executing requests
///-------------------------


/**
 Executes or enqueues a request for execution.

 @param request The request to execute. 

 @return `YES` if the request can be executed/enqueued, `NO` if the request was rejected.

 Requests may be rejected if the execution queue grows too large or if the request itself is invalid (`nil` or already
 cancelled).
 */
- (BOOL)executeRequest:(BBHTTPRequest*)request;


#pragma mark Cleanup

+ (void)cleanup;

@end
