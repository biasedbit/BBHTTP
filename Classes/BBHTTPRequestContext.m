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

#import "BBHTTPRequestContext.h"

#import "BBHTTPRequest+PrivateInterface.h"
#import "BBHTTPUtils.h"



#pragma mark -

@implementation BBHTTPRequestContext
{
    NSMutableArray* _receivedResponses;
    NSOutputStream* _downloadStream;
    NSInputStream* _uploadStream;
}


#pragma mark Creating a request context

- (id)init
{
    NSAssert(NO, @"please use initWithRequest:andHandle: instead");
    return nil;
}

- (id)initWithRequest:(BBHTTPRequest*)request andCurlHandle:(CURL*)handle
{
    self = [super init];
    if (self != nil) {
        _request = request;
        _handle = handle;

        _uploadAborted = NO;
        _downloadStream = nil;
        _receivedResponses = [NSMutableArray array];
    }

    return self;
}


#pragma mark Managing state transitions

- (BOOL)finishCurrentResponse
{
    if (_currentResponse == nil) return NO;

    if (_downloadStream != nil) {
        if ((_request.downloadToStream == nil) && (_request.downloadToFile == nil)) {
            _currentResponse.data = [_downloadStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
        }

        [_downloadStream close];
        _downloadStream = nil;
    }

    _currentResponse.contentSize = _downloadedBytes;
    [_receivedResponses addObject:_currentResponse];
    if (_currentResponse.code == 100) _uploadAccepted = YES;

    BBHTTPResponse* response = _currentResponse;
    _currentResponse = nil;

    BBHTTPLogDebug(@"%@ | Response with status '%lu' (%@) finished.",
                   self, (unsigned long)response.code, response.message);
    
    return YES;
}

- (void)finishWithError:(NSError*)error
{
    if (_error != nil) _error = error;

    [self finish];
}

- (void)finish
{
    if (_error != nil) {
        [_request executionFailedWithError:_error];
        [self cleanup:NO];

    } else {
        [self finishCurrentResponse];
        [self cleanup:YES];

        BBHTTPResponse* response = [self lastResponse];
        NSAssert(response != nil, @"response is nil?"); // TODO can this ever happen?
        [_request executionFinishedWithFinalResponse:response];
    }
}


#pragma mark Managing the upload

- (BOOL)is100ContinueRequired
{
    return [_request hasHeader:H(Expect) withValue:HV(100Continue)];
}

- (NSInteger)transferInputToBuffer:(uint8_t*)buffer limit:(NSUInteger)limit
{
    if (![_request isUpload]) return -1;

    if (_uploadStream == nil) {
        if (_request.uploadStream != nil) {
            _uploadStream = _request.uploadStream;

        } else if (_request.uploadFile != nil) {
            _uploadStream = [NSInputStream inputStreamWithFileAtPath:_request.uploadFile];
            if (_uploadStream == nil) {
                _error = BBHTTPCreateNSErrorWithReason(BBHTTPErrorCodeUploadFileStreamError,
                                                       @"Couldn't upload file",
                                                       @"File does not exist or cannot be read.");
                return -1;
            }
            BBHTTPLogTrace(@"%@ | Created input stream from file '%@' for upload.", self, _request.uploadFile);

        } else {
            _uploadStream = [NSInputStream inputStreamWithData:_request.uploadData];
            if (_uploadStream == nil) {
                _error = BBHTTPCreateNSErrorWithReason(BBHTTPErrorCodeUploadDataStreamError,
                                                       @"Couldn't upload data",
                                                       @"Upload data is not instance of NSData.");
                return -1;
            }
            BBHTTPLogTrace(@"%@ | Created input stream from in-memory NSData for upload.", self);
        }

        [_uploadStream open];
    }

    NSInteger read = [_uploadStream read:buffer maxLength:limit];
    if (read <= 0) {
        BBHTTPLogTrace(@"%@ | Upload stream read %@, closing stream...", self, read == 0 ? @"finished" : @"error");
        [_uploadStream close];
        _uploadStream = nil;
    } else {
        _uploadedBytes += read;
        [_request uploadProgressedToCurrent:_uploadedBytes ofTotal:_request.uploadSize];
    }

    return read;
}


#pragma mark Reading data from the server

- (BOOL)beginResponseWithLine:(NSString*)line
{
    if (_currentResponse != nil) [self finishCurrentResponse];

    _uploadedBytes = 0;
    _downloadSize = 0;
    _downloadedBytes = 0;
    _currentResponse = [BBHTTPResponse responseWithStatusLine:line];
    if (_currentResponse == nil) return NO;

    BBHTTPLogDebug(@"%@ | Receiving response with line '%@'.", self, line);
    if ([_request isUpload] && (_currentResponse.code >= 300)) {
        _uploadAborted = YES;
        BBHTTPLogTrace(@"%@ | ShouldAbortUpload flag set (final non-success response received)", self);
    }

    return YES;
}

- (BOOL)addHeaderToCurrentResponse:(NSString*)line
{
    if (_currentResponse == nil) return NO;

    return [self parseHeaderLine:line andAddToResponse:_currentResponse];
}

- (BOOL)appendDataToCurrentResponse:(uint8_t*)bytes withLength:(NSUInteger)length
{
    if (_currentResponse == nil) return NO;

    if (_downloadStream == nil) {
        if (_request.downloadToStream != nil) {
            _downloadStream = _request.downloadToStream;
        } else if (_request.downloadToFile != nil) {
            _downloadStream = [NSOutputStream outputStreamToFileAtPath:_request.downloadToFile append:NO];
        } else {
            _downloadStream = [NSOutputStream outputStreamToMemory];
        }
        [_downloadStream open];

        if (![_downloadStream hasSpaceAvailable]) {
            _error = BBHTTPCreateNSErrorWithReason(BBHTTPErrorCodeDownloadCannotWriteToStream,
                                                   @"Couldn't read response body",
                                                   @"Download stream/file cannot be written to.");
            return NO;
        }
    }

    NSInteger written = [_downloadStream write:bytes maxLength:length];
    if (written == -1) {
        BBHTTPLogWarn(@"%@ | Error writing to response stream.", self);
        [_downloadStream close];
        _downloadStream = nil;
        return NO;
    } else if (written < length) {
        BBHTTPLogWarn(@"%@ | Could only write %ld bytes to stream (expecting %lu)",
                      self, (long)written, (unsigned long)length);
        [_downloadStream close];
        _downloadStream = nil;
        return NO;
    }

    _downloadedBytes += length;
    [_request downloadProgressedToCurrent:_downloadedBytes ofTotal:_downloadSize];
    
    return YES;
}


#pragma mark Querying context information

- (BBHTTPResponse*)lastResponse
{
    return [_receivedResponses lastObject];
}


#pragma mark Private helpers

- (BOOL)parseHeaderLine:(NSString*)headerLine andAddToResponse:(BBHTTPResponse*)response
{
    if (headerLine == nil) return NO;

    NSRange range = [headerLine rangeOfString:@": "];
    if (range.location == NSNotFound) return NO;

    NSString* headerName = [headerLine substringToIndex:range.location];
    NSString* headerValue = [headerLine substringFromIndex:NSMaxRange(range)];
    [response setValue:headerValue forHeader:headerName];

    // If it's the Content-Length header, set our expected download size
    if ([headerName isEqualToString:H(ContentLength)]) _downloadSize = [headerValue integerValue];

    BBHTTPLogTrace(@"%@ | Received header '%@: %@'.", self, headerName, headerValue);

    return YES;
}

- (void)cleanup:(BOOL)success
{
    if (_uploadStream != nil) [_uploadStream close];
    if (_downloadStream != nil) [_downloadStream close];

    if (!success && (_request.downloadToFile != nil) && (_downloadStream != nil)) {
        [self deleteFileInBackground:_request.downloadToFile];
    }
}

- (void)deleteFileInBackground:(NSString*)file
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSError* error = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:file error:&error]) {
            NSError* cause = [[error userInfo] objectForKey:NSUnderlyingErrorKey];
            NSString* description = cause == nil ? [error localizedDescription] : [cause localizedDescription];
            BBHTTPLogWarn(@"[%@] Deletion of partially downloaded file '%@' failed: %@", self, file, description);
        } else {
            BBHTTPLogTrace(@"[%@] Deleted partially downloaded file '%@'.", self, file);
        }
    });
}


#pragma mark Debug

- (NSString*)description
{
    return [_request description];
}

@end
