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
    NSInputStream* _uploadStream;
    BOOL _discardBodyForCurrentResponse;
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
        _receivedResponses = [NSMutableArray array];
    }

    return self;
}


#pragma mark Managing state transitions

- (BOOL)finishCurrentResponse
{
    if (_currentResponse == nil) return NO;

    id parsedContent = nil;

    if (_currentResponse.code == 100) {
        _uploadAccepted = YES;
    } else if (!_discardBodyForCurrentResponse) {
        NSError* error = nil;
        parsedContent = [_request.responseContentHandler parseContent:&error];

        if (error != nil) _error = error;
    }

    [_currentResponse finishWithContent:parsedContent size:_downloadedBytes successful:(_error == nil)];
    BBHTTPResponse* response = _currentResponse;
    _currentResponse = nil;
    [_receivedResponses addObject:response];

    if (_error != nil) {
        BBHTTPLogDebug(@"%@ | Response with status '%lu' (%@) finished with error parsing content: %@.",
                       self, (unsigned long)response.code, response.message, [_error localizedDescription]);
        return NO;
    } else {
        BBHTTPLogDebug(@"%@ | Response with status '%lu' (%@) finished.",
                       self, (unsigned long)response.code, response.message);
        return YES;
    }
}

- (void)finishWithError:(NSError*)error
{
    if (_error == nil) _error = error;

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
    _discardBodyForCurrentResponse = NO;
    _currentResponse = [BBHTTPResponse responseWithStatusLine:line];
    if (_currentResponse == nil) return NO; // May happen if line is not a valid status response line

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
    if (_discardBodyForCurrentResponse) return YES;

    if (_downloadedBytes == 0) { // first piece of response body arrives
        if (_request.responseContentHandler == nil) {
            _discardBodyForCurrentResponse = YES;
            return YES;
        }

        NSError* error = nil;
        BOOL parserAcceptsResponse = [_request.responseContentHandler
                                      prepareWithResponse:_currentResponse.code message:_currentResponse.message
                                      headers:_currentResponse.headers error:&error];

        if (!parserAcceptsResponse) {
            _discardBodyForCurrentResponse = YES;
            if (error != nil) _error = error;
        }

        if (_error != nil) {
            BBHTTPLogError(@"%@ | Request handler rejected %lu %@ response with error: %@",
                           self, (unsigned long)_currentResponse.code, _currentResponse.message,
                           [_error localizedDescription]);
            return NO;
        }

        // fall to code below
    }

    if ([self transferBytes:bytes withLength:length toHandler:_request.responseContentHandler]) {
        _downloadedBytes += length;
        [_request downloadProgressedToCurrent:_downloadedBytes ofTotal:_downloadSize];
        return YES;
    }

    return NO;
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

- (BOOL)transferBytes:(uint8_t*)bytes withLength:(NSUInteger)length toHandler:(id<BBHTTPContentHandler>)handler
{
    NSError* error = nil;
    NSInteger written = [handler appendResponseBytes:bytes withLength:length error:&error];
    if (error != nil) {
        _error = error;
        return NO;
    } else if (written < length) {
        _error = BBHTTPCreateNSErrorWithReason(BBHTTPErrorCodeDownloadCannotWriteToHandler,
                                               @"Error handling response content",
                                               @"Response handler capacity reached before content was fully read.");
        BBHTTPLogError(@"%@ | Could only write %ld bytes to response handler (expecting %lu)",
                       self, (long)written, (unsigned long)length);
        return NO;
    }

    return YES;
}

- (void)cleanup:(BOOL)success
{
    if (_uploadStream != nil) [_uploadStream close];
}

#pragma mark Debug

- (NSString*)description
{
    return [_request description];
}

@end
