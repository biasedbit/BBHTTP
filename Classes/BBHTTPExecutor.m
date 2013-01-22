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
//  Created by Bruno de Carvalho (@biasedbit, http://biasedbit.com)
//  Copyright (c) 2013 BiasedBit. All rights reserved.
//

#import "BBHTTPExecutor.h"

#import "BBHTTPRequestContext.h"
#import "BBHTTPRequest+PrivateInterface.h"
#import "BBHTTPUtils.h"
#import "curl.h"



#pragma mark - Constants

NSUInteger const kBBHTTPExecutorTinyUpload = 8192;



#pragma mark - Callback helpers

static NSString* BBHTTPExecutorConvertToNSString(uint8_t* buffer, size_t length)
{
    NSString* line = [[NSString alloc] initWithBytes:buffer length:length encoding:NSUTF8StringEncoding];
    return [line stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

static BOOL BBHTTPExecutorIsFinalHeader(uint8_t* buffer, size_t byteSize, size_t length)
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
    context.state = BBHTTPResponseStateReadingHeaders;

    return length;
}

static size_t BBHTTPExecutorReadHeader(uint8_t* buffer, size_t size, size_t length, BBHTTPRequestContext* context)
{
    if (BBHTTPExecutorIsFinalHeader(buffer, size, length)) { // Finished receiving headers
        BBHTTPResponse* currentResponse = [context currentResponse];
        if (currentResponse.code == 100) {
            // 100-Continue responses cannot contain body so we switch state to read status line which will
            // cause the next call to this callback to create a new response
            [context finishCurrentResponse];

            // Subsequent callbacks will hit BBHTTPExecutorReadStatusLine()
            context.state = BBHTTPResponseStateReadingStatusLine;
        } else {
            // Subsequent callbacks will hit BBHTTPExecutorAppendData()
            context.state = BBHTTPResponseStateReadingData;
        }

        // If upload was paused, unpause it. We either got 100-Continue or any other response will be considered error.
        if (context.uploadPaused) {
            BBHTTPLogTrace(@"%@ | Response received (%lu) and upload was paused; unpausing...",
                           context, (unsigned long)currentResponse.code);
            context.uploadPaused = NO;
            curl_easy_pause(context.handle, CURLPAUSE_SEND_CONT);
        }
    } else {
        NSString* headerLine = BBHTTPExecutorConvertToNSString(buffer, length);
        BBHTTPEnsureSuccessOrReturn0([context addHeaderToCurrentResponse:headerLine]);
    }

    return length;
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
    if (![context.request isUpload]) return 0; // Never happens, but...
    if (context.uploadAborted) return 0;

    if (context.uploadAccepted) {
        NSInteger written = [context transferInputToBuffer:buffer limit:length];
        BBHTTPLogTrace(@"%@ | Wrote %ld (max: %lu) bytes to server", context, (long)written, length);
        return written;

    } else {
        // Curl has a hardcoded 1 second hiatus for 100-Continue. While that's a decent value under normal
        // circumstances, it's still a very short window. Thus, even if curl decides it's time to start writing to the
        // server (even though 100-Continue hasn't been received), we hold upload until we receive it. This may cause
        // the request to fail due to timeout.
        context.uploadPaused = YES;
        BBHTTPLogTrace(@"%@ | ReadCallback: 100-Continue hasn't been received yet, holding off upload.", context);
        return CURL_READFUNC_PAUSE;
    }
}

static size_t BBHTTPExecutorReceiveCallback(uint8_t* buffer, size_t size, size_t length, BBHTTPRequestContext* context)
{
    switch (context.state) {
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


#pragma mark Creation

- (id)initWithId:(NSString*)identifier
{
    self = [super init];
    if (self != nil) {
        _maxParallelRequests = 3;
        _maxQueueSize = 1024;

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

- (id)init
{
    NSAssert(NO, @"please use initWithId: instead");

    // Fallback, just in case assertions are off...
    return [self initWithId:@"Default"];
}

+ (instancetype)sharedExecutor
{
    BBHTTPCreateSingleton(instance, BBHTTPExecutor*, [[self alloc] initWithId:@"Shared"]);

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
            [self createContextAndExecuteRequest:request];
        }

        accepted = YES;
    });

    return accepted;
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
        handle = (CURL*)[handleWrapper pointerValue];
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
        context.uploadAccepted = NO;
    } else {
        // Don't wait for 100-Continue from the server, just pump data after sending headers.
        context.uploadAccepted = YES;
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

        if (nextRequest == nil) return; // No more requests queued, bail out
        if (nextRequest.cancelled) continue; // Loop again to find an executable request

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

    if (_verbose) curl_easy_setopt(handle, CURLOPT_VERBOSE, 1);

    // Setup - request line
    if (request.version == BBHTTPProtocolVersion_1_0) {
        curl_easy_setopt(handle, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_0);
    } else if (request.version == BBHTTPProtocolVersion_1_0) {
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
    curl_easy_setopt(handle, CURLOPT_HEADER, YES);
    curl_easy_setopt(handle, CURLOPT_HTTPHEADER, headers);

    // Setup - prepare upload if required
    if ([request isUpload]) {
        curl_easy_setopt(handle, CURLOPT_UPLOAD, YES);
        curl_easy_setopt(handle, CURLOPT_INFILESIZE, [request uploadSize]);
        curl_easy_setopt(handle, CURLOPT_READFUNCTION, BBHTTPExecutorSendCallback);
        curl_easy_setopt(handle, CURLOPT_READDATA, context);
    } else {
        curl_easy_setopt(handle, CURLOPT_UPLOAD, NO);
        curl_easy_setopt(handle, CURLOPT_INFILESIZE, 0);
        curl_easy_setopt(handle, CURLOPT_READFUNCTION, NULL);
        curl_easy_setopt(handle, CURLOPT_READDATA, NULL);
    }

    // Setup - response handling callback
    curl_easy_setopt(handle, CURLOPT_WRITEFUNCTION, BBHTTPExecutorReceiveCallback);
    curl_easy_setopt(handle, CURLOPT_WRITEDATA, context);

    // Setup - configure timeouts
    curl_easy_setopt(handle, CURLOPT_CONNECTTIMEOUT, context.request.connectionTimeout);
    curl_easy_setopt(handle, CURLOPT_TIMEOUT, context.request.responseReadTimeout);

    // Setup - configure redirections
    if (context.request.maxRedirects == 0) {
        curl_easy_setopt(handle, CURLOPT_FOLLOWLOCATION, NO);
    } else {
        curl_easy_setopt(handle, CURLOPT_FOLLOWLOCATION, YES);
        curl_easy_setopt(handle, CURLOPT_MAXREDIRS, context.request.maxRedirects);
    }

    // Setup - misc configuration
    curl_easy_setopt(handle, CURLOPT_NOPROGRESS, YES);
    curl_easy_setopt(handle, CURLOPT_FAILONERROR, NO); // Handle >= 400 codes as success at this layer
    curl_easy_setopt(handle, CURLOPT_SSL_VERIFYPEER, !context.request.allowInvalidSSLCertificates);

    // Emit start notification
    [request executionStarted];

    // Execute
    CURLcode curlResult = curl_easy_perform(handle);

    // Cleanup the headers & resent handle to a pristine state
    curl_slist_free_all(headers);
    curl_easy_reset(handle);

    if (curlResult != CURLE_OK) {
        NSError* error = context.error; // Try and use the error set inside the context or translate libcurl's error
        if (error != nil) {
            [context finish];
        } else {
            error = [self convertCURLCodeToNSError:curlResult context:context];
            [context finishWithError:error];
        }
        BBHTTPLogInfo(@"%@ | Request abnormally terminated.", context);
    } else {
        [context finish];
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
            if (context.uploadPaused) {
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

    if (reason == nil) return BBHTTPCreateNSError(code, description);
    else return BBHTTPCreateNSErrorWithReason(code, description, reason);
}

@end
