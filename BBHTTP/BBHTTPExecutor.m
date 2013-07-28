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

#import "BBHTTPExecutor.h"

#import "BBHTTPRequestContext.h"
#import "BBHTTPRequest+PrivateInterface.h"
#import "BBHTTPUtils.h"



#pragma mark - Constants

NSUInteger const kBBHTTPExecutorTinyUpload = 8192;



#pragma mark - Callback helpers

static NSString* BBHTTPExecutorConvertToNSString(uint8_t* buffer, size_t length)
{
    NSString* line = [[NSString alloc] initWithBytes:buffer length:length encoding:NSUTF8StringEncoding];
    return [line stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

static BOOL BBHTTPExecutorIsFinalHeader(uint8_t* buffer, size_t size, size_t length)
{
    if (length != 2) return NO;
    if (buffer[0] == '\r' && buffer[1] == '\n') return YES;

    return NO;
}

static size_t BBHTTPExecutorReadStatusLine(uint8_t* buffer, size_t size, size_t length, BBHTTPRequestContext* context)
{
    NSString* line = BBHTTPExecutorConvertToNSString(buffer, length);
    BBHTTPEnsureSuccessOrReturn0([context beginResponseWithLine:line]);

    // Subsequent callbacks will hit BBHTTPExecutorReadHeader()
    return length;
}

static size_t BBHTTPExecutorReadHeader(uint8_t* buffer, size_t size, size_t length, BBHTTPRequestContext* context)
{
    BOOL endOfHeaders = BBHTTPExecutorIsFinalHeader(buffer, size, length);

    if (!endOfHeaders) {
        NSString* headerLine = BBHTTPExecutorConvertToNSString(buffer, length);
        BBHTTPEnsureSuccessOrReturn0([context addHeaderToCurrentResponse:headerLine]);

        // Subsequent callbacks will keep hitting BBHTTPExecutorReadHeader()
        return length;
    }

    // End of headers reached, data will follow
    BBHTTPLogTrace(@"%@ | All headers received.", context);
    BOOL canProceed = YES;
    if ([context isCurrentResponse100Continue]) {
        // Subsequent callbacks will hit BBHTTPExecutorReadStatusLine()
        [context finishCurrentResponse];
    } else {
        // Subsequent callbacks will hit BBHTTPExecutorAppendData()
        // Response content handler may reject (or fail to accept) this request, in which case this will return NO
        canProceed = [context prepareToReceiveData];
    }

    // If upload was paused, we always have to unpause it, otherwise curl gets stuck.
    if ([context isUploadPaused]) {
        BBHTTPLogTrace(@"%@ | Response received (%lu) and upload was paused; unpausing...",
                       context, (unsigned long)[context currentResponse].code);
        [context unpauseUpload];
        curl_easy_pause(context.handle, CURLPAUSE_SEND_CONT);
    }

    return canProceed ? length : 0;
}

static size_t BBHTTPExecutorAppendData(uint8_t* buffer, size_t size, size_t length, BBHTTPRequestContext* context)
{
    BBHTTPEnsureSuccessOrReturn0([context appendDataToCurrentResponse:buffer withLength:length]);

    return length;
}



#pragma mark - Curl callback functions

static size_t BBHTTPExecutorSendCallback(uint8_t* buffer, size_t size, size_t length, BBHTTPRequestContext* context)
{
    if (length == 0) return 0;

    if ([context.request wasCancelled] ||
        ![context.request isUpload] ||
        [context hasUploadBeenAborted]) return CURL_READFUNC_ABORT;

    if ([context hasUploadBeenAccepted]) {
        NSInteger transferred = [context transferInputToBuffer:buffer limit:length];
        return (transferred > 0) ? (size_t)transferred : CURL_READFUNC_ABORT;

    } else {
        // Curl has a hardcoded 1 second hiatus for 100-Continue. While that's a decent value under normal
        // circumstances, it's still a very short window. Thus, even if curl decides it's time to start writing to the
        // server (even though 100-Continue hasn't been received), we hold upload until we receive it. This may cause
        // the request to fail due to timeout.
        [context pauseUpload];
        BBHTTPLogTrace(@"%@ | ReadCallback: 100-Continue hasn't been received yet, holding off upload.", context);
        return CURL_READFUNC_PAUSE;
    }
}

static size_t BBHTTPExecutorReceiveCallback(uint8_t* buffer, size_t size, size_t length, BBHTTPRequestContext* context)
{
    if ([context.request wasCancelled]) return 0;

    switch (context.state) {
        case BBHTTPResponseStateReady:
        case BBHTTPResponseStateReadingStatusLine:
            return BBHTTPExecutorReadStatusLine(buffer, size, length, context);

        case BBHTTPResponseStateReadingHeaders:
            return BBHTTPExecutorReadHeader(buffer, size, length, context);

        case BBHTTPResponseStateReadingData:
            return BBHTTPExecutorAppendData(buffer, size, length, context);

        default:
            // never happens...
            return 0;
    }
}

static int BBHTTPExecutorDebugCallback(CURL* handle, curl_infotype type, char* text, size_t length, void* context)
{
    switch (type) {
        case CURLINFO_TEXT: {
            NSString* message = [[NSString alloc] initWithBytes:text length:length encoding:NSASCIIStringEncoding];
            BBHTTPCurlDebug(@"%@", message);
            break;
        }

        case CURLINFO_DATA_IN:
            BBHTTPCurlDebug(@"DATA IN << %lub", (unsigned long)length);
            break;

        case CURLINFO_DATA_OUT:
            BBHTTPCurlDebug(@"DATA OUT >> %lub", (unsigned long)length);
            break;

        case CURLINFO_SSL_DATA_IN:
            BBHTTPCurlDebug(@"SSL DATA IN << %lub", (unsigned long)length);
            break;

        case CURLINFO_SSL_DATA_OUT:
            BBHTTPCurlDebug(@"SSL DATA OUT >> %lub", (unsigned long)length);
            break;

        default: // ignored
            break;
    }

    return 0;
}



#pragma mark -

@implementation BBHTTPExecutor
{
    dispatch_queue_t _synchronizationQueue;
    dispatch_queue_t _requestExecutionQueue;

    NSMutableArray* _running;
    NSMutableArray* _queued;

    NSMutableArray* _availableCurlHandles;
    NSMutableArray* _allCurlHandles;
}

static BOOL BBHTTPExecutorInitialized = NO;


#pragma mark Class creation

+ (void)initialize
{
    [super initialize];

    if (!BBHTTPExecutorInitialized) {
        CURLcode result = curl_global_init(CURL_GLOBAL_ALL);
        if (result != CURLE_OK) {
            BBHTTPLogError(@"curl_global_init() failed with code %d; some functionalities may be impaired.", result);
        } else {
            BBHTTPLogInfo(@"curl_global_init() successfully executed; BBHTTP booted with libcurl '%s'.",
                          LIBCURL_VERSION);
            BBHTTPExecutorInitialized = YES;
        }
    }
}


#pragma mark Creation

- (instancetype)initWithId:(NSString*)identifier
{
    self = [super init];
    if (self != nil) {
        _maxParallelRequests = 3;
        _maxQueueSize = 1024;

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
        _manageNetworkActivityIndicator = YES;
#endif

        _running = [NSMutableArray array];
        _queued = [NSMutableArray array];

        _availableCurlHandles = [NSMutableArray array];
        _allCurlHandles = [NSMutableArray array];

        NSString* syncQueueId = [NSString stringWithFormat:@"com.biasedbit.HTTPExecutorSyncQueue-%@", identifier];
        _synchronizationQueue = dispatch_queue_create([syncQueueId UTF8String], DISPATCH_QUEUE_SERIAL);

        NSString* requestQueueId = [NSString stringWithFormat:@"com.biasedbit.HTTPExecutorRequestQueue-%@", identifier];
        _requestExecutionQueue = dispatch_queue_create([requestQueueId UTF8String], DISPATCH_QUEUE_CONCURRENT);
    }

    return self;
}

- (instancetype)init
{
    NSAssert(NO, @"please use initWithId: instead");

    // Fallback, just in case assertions are off...
    return [self initWithId:@"Default"];
}

+ (instancetype)sharedExecutor
{
    BBHTTPSingleton(BBHTTPExecutor, instance, [[self alloc] initWithId:@"Shared"]);

    return instance;
}


#pragma mark Destruction

- (void)dealloc
{
    for (NSValue* handleWrapper in _allCurlHandles) {
        CURL* handle = [handleWrapper pointerValue];
        curl_easy_cleanup(handle);
    }

#if !OS_OBJECT_USE_OBJC
    dispatch_release(_synchronizationQueue);
    dispatch_release(_requestExecutionQueue);
#endif
}


#pragma mark Configuring behavior

- (void)setMaxParallelRequests:(NSUInteger)maxParallelRequests
{
    NSParameterAssert(maxParallelRequests >= 1);
    _maxParallelRequests = maxParallelRequests;
}


#pragma mark Performing requests

- (BOOL)executeRequest:(BBHTTPRequest*)request
{
    if (request == nil) return NO;

    __block BOOL accepted = NO;
    dispatch_sync(_synchronizationQueue, ^{
        if (request.cancelled) return; // already cancelled
        if ([self isAlreadyRunningOrQueued:request]) return;

        if ([_running count] >= _maxParallelRequests) {
            [self enqueueRequest:request];
        } else {
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
            if (([_running count] == 0) && _manageNetworkActivityIndicator)
                [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
#endif
            [self createContextAndExecuteRequest:request];
        }

        accepted = YES;
    });

    return accepted;
}


#pragma mark Cleanup

+ (void)cleanup
{
    if (BBHTTPExecutorInitialized) {
        curl_global_cleanup();
        BBHTTPExecutorInitialized = NO;
        BBHTTPLogInfo(@"curl_global_cleanup() performed.");
    }
}


#pragma mark Private helpers

- (CURL*)getOrCreatePooledCurlHandle
{
    CURL* handle;

    if ([_availableCurlHandles count] == 0) {
        handle = curl_easy_init();
        NSValue* handleWrapper = [NSValue valueWithPointer:handle];
        [_allCurlHandles addObject:handleWrapper];
    } else {
        NSValue* handleWrapper = _availableCurlHandles[0];
        [_availableCurlHandles removeObjectAtIndex:0];
        handle = [handleWrapper pointerValue];
    }

    return handle;
}

- (void)prepareContextForExecution:(BBHTTPRequestContext*)context
{
    BBHTTPRequest* request = context.request;

    if ((request.version == BBHTTPProtocolVersion_1_1) &&
        !request.dontSendExpect100Continue &&
        [request isUpload] &&
        ([request uploadSize] > kBBHTTPExecutorTinyUpload) &&
        ![request hasHeader:H(Expect) withValue:HV(100Continue)]) {

        BBHTTPLogDebug(@"%@ | Adding 'Expect: 100-Continue' header to request (upload size > %lu)",
                       context, (long)kBBHTTPExecutorTinyUpload);
        [request setValue:HV(100Continue) forHeader:H(Expect)];
    }

    if ([context is100ContinueRequired]) {
        // Whenever we send out the Expect: 100-Continue header, we first must receive confirmation before sending data.
        // This part is just the setup, check out BBHTTPExecutorSendCallback() for the logic.
        [context waitFor100ContinueBeforeUploading];
    }

    if ([request isUpload] &&
        (request.chunkedTransfer || ![request isUploadSizeKnown])) {
        BBHTTPLogDebug(@"%@ | Upload size is unknown, adding 'Transfer-Encoding: chunked' header.", context);
        [request setValue:HV(Chunked) forHeader:H(TransferEncoding)];
    }
}

- (void)createContextAndExecuteRequest:(BBHTTPRequest*)request
{
    CURL* handle = [self getOrCreatePooledCurlHandle];
    BBHTTPRequestContext* context = [[BBHTTPRequestContext alloc] initWithRequest:request andCurlHandle:handle];
    [self prepareContextForExecution:context];
    [self addToRunning:request];

    dispatch_async(_requestExecutionQueue, ^{
        [self executeContext:context withCurlHandle:handle];

        dispatch_sync(_synchronizationQueue, ^{
            [self removeFromRunning:request];
            [self returnHandle:handle];

            [self executeNextRequest];
        });
    });
}

- (void)executeNextRequest
{
    while (true) {
        BBHTTPRequest* nextRequest = [self popQueuedRequest];

        if (nextRequest == nil) { // No more requests queued, bail out
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
            // Last request to finish stops the activity indicator
            if (([_running count] == 0) && _manageNetworkActivityIndicator)
                [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
#endif
            return;
        }

        if ([nextRequest wasCancelled]) continue; // Loop again to find an executable request

        // Executable operation found, break the loop; next operation finishing will trigger this method again
        [self createContextAndExecuteRequest:nextRequest];
        return;
    }
}

- (BOOL)isAlreadyRunningOrQueued:(BBHTTPRequest*)request
{
    return [_running containsObject:request] || [_queued containsObject:request];
}

- (void)enqueueRequest:(BBHTTPRequest*)request
{
    [_queued addObject:request];
}

- (void)addToRunning:(BBHTTPRequest*)request
{
    [_running addObject:request];
}

- (void)removeFromRunning:(BBHTTPRequest*)request
{
    [_running removeObject:request];
}

- (BBHTTPRequest*)popQueuedRequest
{
    if ([_queued count] == 0) return nil;

    BBHTTPRequest* request = _queued[0];
    [_queued removeObjectAtIndex:0];
    
    return request;
}

- (void)executeContext:(BBHTTPRequestContext*)context withCurlHandle:(CURL*)handle
{
    BBHTTPRequest* request = context.request;

    // Handle setup
    curl_easy_setopt(handle, CURLOPT_NOSIGNAL, 1L); // If this isn't set, curl will eventually crash the app
    curl_easy_setopt(handle, CURLOPT_FORBID_REUSE, _dontReuseConnections ? 1L : 0L);
    if (_verbose) {
        curl_easy_setopt(handle, CURLOPT_VERBOSE, 1L);
        curl_easy_setopt(handle, CURLOPT_DEBUGFUNCTION, BBHTTPExecutorDebugCallback);
    }

    // Setup - request line
    if (request.version == BBHTTPProtocolVersion_1_0) {
        curl_easy_setopt(handle, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_0);
    } else if (request.version == BBHTTPProtocolVersion_1_1) {
        curl_easy_setopt(handle, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
    } // else leave it up to libcurl to decide

    const char* verb = [request.verb UTF8String];
    curl_easy_setopt(handle, CURLOPT_CUSTOMREQUEST, verb);

    const char* url = [[request.url absoluteString] UTF8String];
    curl_easy_setopt(handle, CURLOPT_URL, url);


    // Setup - headers
    __block struct curl_slist* headers = NULL;
    [request.headers enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSString* value, BOOL* stop) {
        const char* header = [[NSString stringWithFormat:@"%@: %@", key, value] UTF8String];
        headers = curl_slist_append(headers, header);
    }];
    if (![request hasHeader:H(Expect)] && [request isUpload]) {
        // if Expect header wasn't set until now, make sure libcurl doesn't add it
        curl_slist_append(headers, "Expect: ");
    }

    curl_easy_setopt(handle, CURLOPT_HEADER, 1L);
    curl_easy_setopt(handle, CURLOPT_HTTPHEADER, headers);

    // Setup - prepare upload if required
    if ([request isUpload]) {
        curl_easy_setopt(handle, CURLOPT_UPLOAD, 1L);
        curl_easy_setopt(handle, CURLOPT_INFILESIZE, [request uploadSize]);
        curl_easy_setopt(handle, CURLOPT_READFUNCTION, BBHTTPExecutorSendCallback);
        curl_easy_setopt(handle, CURLOPT_READDATA, context);
    } else {
        curl_easy_setopt(handle, CURLOPT_UPLOAD, 0L);
        curl_easy_setopt(handle, CURLOPT_INFILESIZE, 0L);
        curl_easy_setopt(handle, CURLOPT_READFUNCTION, NULL);
        curl_easy_setopt(handle, CURLOPT_READDATA, NULL);
    }

    // Setup - response handling callback
    curl_easy_setopt(handle, CURLOPT_WRITEFUNCTION, BBHTTPExecutorReceiveCallback);
    curl_easy_setopt(handle, CURLOPT_WRITEDATA, context);

    // Setup - configure timeouts
    curl_easy_setopt(handle, CURLOPT_CONNECTTIMEOUT, context.request.connectionTimeout);
    curl_easy_setopt(handle, CURLOPT_LOW_SPEED_LIMIT, context.request.downloadTimeout.bytesPerSecond);
    curl_easy_setopt(handle, CURLOPT_LOW_SPEED_TIME, context.request.downloadTimeout.duration);

    // Setup - speed limits
    if ([context.request isUpload] && (context.request.uploadSpeedLimit > 0)) {
        curl_easy_setopt(handle, CURLOPT_MAX_SEND_SPEED_LARGE, context.request.uploadSpeedLimit);
    }

    if (context.request.downloadSpeedLimit > 0) {
        curl_easy_setopt(handle, CURLOPT_MAX_RECV_SPEED_LARGE, context.request.downloadSpeedLimit);
    }

    // Setup - configure redirections
//    if (context.request.maxRedirects == 0) {
//        curl_easy_setopt(handle, CURLOPT_FOLLOWLOCATION, NO);
//    } else {
//        curl_easy_setopt(handle, CURLOPT_FOLLOWLOCATION, YES);
//        curl_easy_setopt(handle, CURLOPT_MAXREDIRS, context.request.maxRedirects);
//    }

    // Setup - misc configuration
    curl_easy_setopt(handle, CURLOPT_NOPROGRESS, 1L);
    curl_easy_setopt(handle, CURLOPT_FAILONERROR, 0L); // Handle >= 400 codes as success at this layer
    curl_easy_setopt(handle, CURLOPT_SSL_VERIFYPEER, context.request.allowInvalidSSLCertificates ? 0L : 1L);

    BBHTTPLogInfo(@"%@ | Request starting…", context);

    // Emit start notification
    [request executionStarted];

    // Execute
    CURLcode curlResult = curl_easy_perform(handle);

    // Cleanup the headers & reset handle to a pristine state
    curl_slist_free_all(headers);
    curl_easy_reset(handle);

    if ([request wasCancelled]) {
        BBHTTPSingleton(NSError, cancelError, BBHTTPError(BBHTTPErrorCodeCancelled, @"Request cancelled."));
        [context requestFinishedWithError:cancelError];
        BBHTTPLogInfo(@"%@ | Request cancelled.", context);

    } else if (curlResult != CURLE_OK) {
        NSError* error = context.error;
        if (error != nil) {
            [context requestFinished];
        } else {
            error = [self convertCURLCodeToNSError:curlResult context:context];
            [context requestFinishedWithError:error];
        }
        BBHTTPLogInfo(@"%@ | Request abnormally terminated: %@", context, [error localizedDescription]);

    } else {
        [context requestFinished];
        BBHTTPLogInfo(@"%@ | Request finished.", context);
    }
}

- (void)returnHandle:(CURL*)handle
{
    [_availableCurlHandles addObject:[NSValue valueWithPointer:handle]];
}

- (NSError*)convertCURLCodeToNSError:(CURLcode)code context:(BBHTTPRequestContext*)context
{
    // Convert CURLcode into a human readable string and, whenever necessary, append some detailed explanation

    // Default to curl_easy_strerror, override when deemed necessary
    NSString* description = [NSString stringWithCString:curl_easy_strerror(code) encoding:NSUTF8StringEncoding];
    NSString* reason = nil;

    // Details from http://curl.haxx.se/libcurl/c/libcurl-errors.html
    switch (code) {
        case CURLE_UNSUPPORTED_PROTOCOL: // 1
            reason = @"The URL you passed to libcurl used a protocol that this libcurl does not support. "
                     "The support might be a compile-time option that you didn't use, it can be a misspelled protocol "
                     "string or just a protocol libcurl has no code for.";
            break;

        case CURLE_FAILED_INIT: // 2
            reason = @"Very early initialization code failed. This is likely to be an internal error or problem, or a "
                      "resource problem where something fundamental couldn't get done at init time.";
            break;

        case CURLE_URL_MALFORMAT: // 3
            reason = @"The URL was not properly formatted.";
            break;

        case CURLE_NOT_BUILT_IN: // 4
            reason = @"A requested feature, protocol or option was not found built-in in this libcurl due to a "
                      "build-time decision.";
            break;

        case CURLE_COULDNT_RESOLVE_PROXY: // 5
            reason = @"The given proxy host could not be resolved.";
            break;

        case CURLE_COULDNT_RESOLVE_HOST: // 6
            reason = @"The given remote host was not resolved.";
            break;

        case CURLE_COULDNT_CONNECT: // 7
            break;

        case CURLE_PARTIAL_FILE: // 18
            reason = @"This happens when the server first reports an expected transfer size, and then delivers data "
                      "that doesn't match the previously given size.";
            break;

        case CURLE_HTTP_RETURNED_ERROR: // 22
            break;

        case CURLE_WRITE_ERROR: // 23
            reason = @"An error occurred when writing received data to a local file, or an error was returned to "
                      "libcurl from a write callback.";
            break;

        case CURLE_READ_ERROR: // 26
            reason = @"There was a problem reading a local file or an error returned by the read callback.";
            break;

        case CURLE_OUT_OF_MEMORY: // 27 - Shit has seriously hit the fan!
            break;

        case CURLE_OPERATION_TIMEDOUT: // 28
            // Since we manually pause the upload until we receive 100-Continue, a timeout may occur. If that happens,
            // make sure we convey the correct error message.
            if ([context isUploadPaused]) {
                description = @"Expectation failed";
                reason = @"Request timed out while waiting for 100-Continue response from the server.";
            }
            break;

        case CURLE_RANGE_ERROR: // 33
            break;

        case CURLE_HTTP_POST_ERROR: // 34
            reason = @"This is an odd error that mainly occurs due to internal confusion."; // lol
            break;

        case CURLE_SSL_CONNECT_ERROR: // 35
            reason = @"A problem occurred somewhere in the SSL/TLS handshake. "
                      "Could be certificates (file formats, paths, permissions), passwords, and others.";
            break;

        case CURLE_BAD_DOWNLOAD_RESUME: // 36
            reason = @"The download could not be resumed because the specified offset was out of the file boundary.";
            break;

        case CURLE_FUNCTION_NOT_FOUND: // 41
            reason = @"A required zlib function was not found.";
            break;

        case CURLE_ABORTED_BY_CALLBACK: // 42
            reason = @"A callback returned 'abort' to libcurl.";
            break;

        case CURLE_BAD_FUNCTION_ARGUMENT: // 43
            description = @"Internal error.";
            reason = @"A function was called with a bad parameter.";
            break;

        case CURLE_INTERFACE_FAILED: // 45
            reason = @"Set which interface to use for outgoing connections' source IP address with CURLOPT_INTERFACE.";
            break;

        case CURLE_TOO_MANY_REDIRECTS: // 47
            reason = @"Redirect limit reached or loop detected.";
            break;

        case CURLE_UNKNOWN_OPTION: // 48
            reason = @"An option passed to libcurl is not recognized/known.";
            break;

        case CURLE_PEER_FAILED_VERIFICATION:
            reason = @"The remote server's SSL certificate or SSH md5 fingerprint was deemed not OK.";
            break;

        case CURLE_GOT_NOTHING: // 52
            break;

        case CURLE_SSL_ENGINE_NOTFOUND: // 53
            break;

        case CURLE_SSL_ENGINE_SETFAILED: // 54
            break;

        case CURLE_SEND_ERROR: // 55
            description = @"Failure sending data to server";
            break;

        case CURLE_RECV_ERROR: // 56
            description = @"Failure receiving data from server";
            break;

        case CURLE_SSL_CERTPROBLEM: // 58
            break;

        case CURLE_SSL_CIPHER: // 59
            break;

        case CURLE_SSL_CACERT: // 60
            break;

        case CURLE_BAD_CONTENT_ENCODING:
            break;

        case CURLE_FILESIZE_EXCEEDED: // 63
            break;

        case CURLE_SSL_ENGINE_INITFAILED: // 66
            break;

        case CURLE_LOGIN_DENIED: // 67
            reason = @"The remote server denied login; double check user and password.";
            break;

        case CURLE_CONV_FAILED: // 75
            break;

        case CURLE_CONV_REQD: // 76
            reason = @"Caller must register conversion callbacks using curl_easy_setopt options "
                      "CURLOPT_CONV_FROM_NETWORK_FUNCTION, CURLOPT_CONV_TO_NETWORK_FUNCTION, and "
                      "CURLOPT_CONV_FROM_UTF8_FUNCTION.";
            break;

        case CURLE_SSL_CACERT_BADFILE: // 77
            reason = @"Could not load CACERT file; missing or wrong format.";
            break;

        case CURLE_REMOTE_FILE_NOT_FOUND: // 78
            reason = @"The resource referenced in the URL does not exist.";
            break;

        case CURLE_SSL_SHUTDOWN_FAILED: // 80
            reason = @"Failed to shut down the SSL connection";
            break;

        case CURLE_SSL_CRL_BADFILE:
            reason = @"Could not load CRL file; missing or wrong format.";
            break;

        case CURLE_SSL_ISSUER_ERROR: // 84
            break;

        case CURLE_CHUNK_FAILED: // 88
            break;

        default:
            reason = [NSString stringWithFormat:@"Unknown libcurl error with code %u", code];
            break;
    }

    if (reason == nil) return BBHTTPError(code, description);
    else return BBHTTPErrorWithReason(code, description, reason);
}

@end
