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

#import "BBHTTPResponse.h"
#import "BBHTTPContentHandler.h"



#pragma mark -

/**
 The `BBHTTPRequest` class represents an HTTP or HTTPS request to a [resource in a remote server](<url>), using a 
 given <verb> and a [protocol version](<version>).

 It contains several properties which will influence how the request will be executed by the `<BBHTTPExecutor>` to which
 they are submitted.
 */
@interface BBHTTPRequest : NSObject
{
@private
    long long _startTimestamp;
    long long _endTimestamp;
    NSUInteger _sentBytes;
    NSUInteger _receivedBytes;
    NSError* _error;
    BBHTTPResponse* _response;
}


#pragma mark Creating a request

/// ------------------------
/// @name Creating a request
/// ------------------------

/**
 Shortcut to `<initWithURL:andVerb:>` that converts the input string into a `NSURL`.

 @param url The target URL.
 @param verb The HTTP verb to use.

 @return An initialized request to *url* using *verb*.
 */
- (id)initWithTarget:(NSString*)url andVerb:(NSString*)verb;

/**
 Initializes a new request with target *url*, using *verb* and HTTP protocol version 1.1.

 @param url The target URL.
 @param verb The HTTP verb to use.

 @return An initialized request to *url* using *verb*.
 
 @see initWithURL:verb:andProtocolVersion:
 */
- (id)initWithURL:(NSURL*)url andVerb:(NSString*)verb;

/**
 Initializes a new request with target *url*, using *verb* and HTTP protocol *version*.

 @param url The target URL.
 @param verb The HTTP verb to use.
 @param version The HTTP protocol version to use.

 @return An initialized request to *url* using *verb* and protocol *version*.
 */
- (id)initWithURL:(NSURL*)url verb:(NSString*)verb andProtocolVersion:(BBHTTPProtocolVersion)version;


#pragma mark Handling request events

/// -----------------------------
/// @name Handling request events
/// -----------------------------

/** Block that will be called when the request execution begins. */
@property(copy, nonatomic) void (^startBlock)();

/**
 Block that will be called when the request terminates, either normally or abnormally.

 This instance is passed as a parameter of the block to avoid the weak/strong dance and allow a fluent code syntax.
 */
@property(copy, nonatomic) void (^finishBlock)(id request);

/**
 Block that will be called every time a new chunk of data is written to the remote server, during the upload phase.
 
 The *total* may be reported as `0` if the upload size is unknown (chunked transfer encoding from a stream).
 */
@property(copy, nonatomic) void (^uploadProgressBlock)(NSUInteger current, NSUInteger total);

/**
 Block that will be called every time a new chunk of data is read from the remote server, during the download phase.

 The *total* may be reported as `0` if the download size is unknown (chunked transfer encoding).
 */
@property(copy, nonatomic) void (^downloadProgressBlock)(NSUInteger current, NSUInteger total);


#pragma mark Managing download behavior

/// --------------------------------
/// @name Managing download behavior
/// --------------------------------

@property(strong, nonatomic) id<BBHTTPContentHandler> responseContentHandler;

/** The download size, in, bytes when available. */
@property(assign, nonatomic, readonly) NSUInteger downloadSize;

@property(assign, nonatomic, readonly) double downloadProgress;
@property(assign, nonatomic, readonly) double downloadTransferRate;


#pragma mark Managing upload behavior

/// ------------------------------ 
/// @name Managing upload behavior
/// ------------------------------

/**
 Configure the upload stream from which this request will read data to perform the upload.
 
 Assigning an input stream to a request will override the file or buffer previously set with `<setUploadFile:error:>` or
 `<setUploadData:withContentType:>`.
 
 If this method returns `YES`, the property `<upload>` will report `YES`.The `Content-Length` header will automatically
 be set as well, provided that *size* is greater than `0`.

 ### Unknown upload size/streaming uploads

 If you do not know the size of the upload beforehand, pass `0` as the *size* is `0`. Beware that by doing so, the
 `<uploadProgressBlock>` calls will pass back `0` for the *total* argument. This means that there will be no way for
 you to accurately calculate actual upload progress.
 
 @warning Passing `0` as *size* will cause the request to use chunked transfer encoding, even if you set
 `<chunkedTransfer>` to `NO`.
 
 Passing `0` is preferrable to passing a wrong value for *size*, as it may lead to incorrect request processing by the
 server.
 
 @param stream The input stream from which data will be read and sent as the upload body.
 @param contentType The value to use on the `Content-Type` header. Must be a valid
 [MIME type](http://tools.ietf.org/html/rfc2046).
 @param size The size of the content that will be provided by the stream. Pass `0` if you do not know this beforehand.

 @return `YES` if this request is HTTP/1.1, `NO` otherwise.
 */
- (BOOL)setUploadStream:(NSInputStream*)stream withContentType:(NSString*)contentType andSize:(NSUInteger)size;

/**
 Set the upload stream, from which this request will read data to perform the upload.

 Assigning an upload file to a request will override the stream or buffer previously set with 
 `<setUploadStream:withContentType:andSize:>` or `<setUploadData:withContentType:>`.
 
 If this method returns `YES`, the property `<upload>` will report `YES`. The `Content-Length` header will automatically
 be set as well.
 
 The value for the `Content-Type` header will be inferred from the file extension. If the file has no extension, it will
 be uploaded with `application/octet-stream` content type.
 
 @param path Absolute path to the file to be uploaded.
 @param error On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error object 
 containing the error information. You may specify nil for this parameter if you do not want the error information.

 @return `YES` if the file can be uploaded, `NO` otherwise &mdash; if the file cannot be read, if it's an empty file or
 its size is too big for upload.
 */
- (BOOL)setUploadFile:(NSString*)path error:(NSError**)error;

/**
 Set a data buffer as the upload body, with the given content type.
 
 If this method returns `YES`, the property `<upload>` will report `YES`. The `Content-Length` header will automatically
 be set as well.

 @param data Data buffer to use as request body.
 @param contentType The value to use on the `Content-Type` header. Must be a valid
 [MIME type](http://tools.ietf.org/html/rfc2046).

 @return `YES` of the buffer is valid, `NO` otherwise &mdash; 0-length buffer.
 */
- (BOOL)setUploadData:(NSData*)data withContentType:(NSString*)contentType;

/** Flag that signals whether this request is an upload (from stream, file or memory). */
@property(assign, nonatomic, readonly, getter = isUpload) BOOL upload;

/**
 Flag that signals whether the size of an upload is known.
 
 If the request is an upload, this flag will always be set to `YES` unless the current request is an upload from a
 stream and the reported upload size was unknown, i.e. `<setUploadStream:withContentType:andSize:>` was called with `0`
 being passed as *size*.

 @see setUploadStream:withContentType:andSize:
 */
@property(assign, nonatomic, readonly, getter = isUploadSizeKnown) BOOL uploadSizeKnown;

/** The size, in bytes, of the upload, if any. */
@property(assign, nonatomic, readonly) NSUInteger uploadSize;

/** The stream from which the upload body will be read, if any. */
@property(strong, nonatomic, readonly) NSInputStream* uploadStream;

/** The file to upload, if any. */
@property(copy, nonatomic) NSString* uploadFile;

/** The in-memory buffer of data to upload, if any. */
@property(retain, nonatomic, readonly) NSData* uploadData;

@property(assign, nonatomic, readonly) double uploadProgress;
@property(assign, nonatomic, readonly) double uploadTransferRate;


#pragma mark Manipulating headers

/// --------------------------
/// @name Manipulating headers
/// --------------------------

/**
 Tests whether the request contains a request with the given name.

 @param header The name of the header to check for.

 @return `YES` if the request contains a header named *header*, `NO` otherwise.

 @see hasHeader:withValue:
 */
- (BOOL)hasHeader:(NSString*)header;

/**
 Tests whether the request contains a request with the given name set to the given value.

 @param header The name of the header to check for.
 @param value The value against which the header value will be compared to.

 @return `YES` if the request contains a header named *header* with value equal to *value*, `NO` otherwise.
 */
- (BOOL)hasHeader:(NSString*)header withValue:(NSString*)value;

/**
 Returns the value of the header with given name.

 @param header The name of the header to retrieve.

 @return The value of the header, if any, `nil` otherwise.
 */
- (NSString*)headerWithName:(NSString*)header;

/**
 Returns the value of the header with given name.
 
 Allows you to use the object dictionary subscript operator on a request, in order to read a header:
 
     NSLog(@"Content-Type: %@", request[@"Content-Type"]);

 @param header The name of the header to retrieve.

 @return The value of the header, if any, `nil` otherwise.
 */
- (NSString*)objectForKeyedSubscript:(NSString*)header;

/**
 Set or replace the value for a given header.
 
 @param value The value to set.
 @param header The header to set.

 @return `YES` if the header was set, `NO` if it was rejected &mdash; either *value* or *header* were `nil` or request
 already started.
 */
- (BOOL)setValue:(NSString*)value forHeader:(NSString*)header;

/**
 Set or replace the value for a given header.

 Allows you to use the object dictionary subscript operator on a request, in order to set a header:
 
     request[@"Content-Type"] = @"text/plain"
 
 @param value The value of the header.
 @param header The name of the header to set.
 */
- (void)setObject:(NSString*)value forKeyedSubscript:(NSString*)header;


#pragma mark Configuring other request properties

/// ------------------------------------------
/// @name Configuring other request properties
/// ------------------------------------------

/**
 Time, in seconds, to wait for a connection to the server.
 
 This value affects **only** the connection stage of the request.
 */
@property(assign, nonatomic) NSUInteger connectionTimeout;

/**
 Inactivity limit, in seconds, before considering the request as timed out.
 
 If a request does not receive data for more than *responseReadTimeout* seconds, the request will fail.
 
 @bug This is not working, for the time being.
 */
@property(assign, nonatomic) NSUInteger responseReadTimeout;

/* TODO: Not yet properly supported. */
@property(assign, nonatomic) NSUInteger maxRedirects;

/**
 Explicitly avoid using the `Expect: 100-Continue` header.

 Do not touch this unless the server responded with a `417` code ("Expectation failed") to your previous request.
 
 If the upload fails with any other code, report the problem and help the internet become better by directing them
 [here](http://tools.ietf.org/html/rfc2616#section-14.20) and [here](http://tools.ietf.org/html/rfc2616#section-8.2.3).

 **Sidenote:** The whole *raison d'être* for this project was to build a client that properly supported upload
 expectations and cope with error responses midway through upload.
 */
@property(assign, nonatomic) BOOL dontSendExpect100Continue;

/**
 Flag that determines whether the body for non successful responses should be discarded.
 
 When this flag is set to `YES` the HTTP response body will be discarded.
 
 Defaults to `YES`.
 */
@property(assign, nonatomic) BOOL discardBodyForNon200Responses;

/**
 Flag that indicates that this request should used chunked transfer encoding.
 
 This flag is ignored if this request is not a `HTTP/1.1` request.
 */
@property(assign, nonatomic) BOOL chunkedTransfer;

/**
 Flag that indicates that the SSL verification of the remote peer should be strict.
 
 When set to `NO` and the remote peer SSL/TLS verification fails, the request will fail.
 */
@property(assign, nonatomic) BOOL allowInvalidSSLCertificates;


#pragma mark Querying request properties

/// ---------------------------------
/// @name Querying request properties
/// ---------------------------------

/** The HTTP protocol this request will be executed under. */
@property(assign, nonatomic, readonly) BBHTTPProtocolVersion version;

/** The target URL for this request */
@property(copy, nonatomic, readonly) NSURL* url;

/** The HTTP verb that will be used when executing the request. */
@property(copy, nonatomic, readonly) NSString* verb;

/**
 Dictionary of all the headers that will be sent along with the request.
 
 Additional headers like `Expect` and `Transfer-Encoding` may be automatically added, depending on the request.

 @see chunkedTransfer
 @see dontSendExpect100Continue
 */
@property(strong, nonatomic, readonly) NSDictionary* headers;

/** The server port against which the connection required to execute this request will be open. */
@property(assign, nonatomic, readonly) NSUInteger port;


#pragma mark Querying request state

/// ----------------------------
/// @name Querying request state
/// ----------------------------

@property(assign, nonatomic, readonly) long long startTimestamp;
@property(assign, nonatomic, readonly) long long endTimestamp;
@property(assign, nonatomic, readonly, getter = hasStarted) BOOL started;
@property(assign, nonatomic, readonly, getter = hasFinished) BOOL finished;
@property(assign, nonatomic, readonly, getter = isExecuting) BOOL executing;
@property(assign, nonatomic, readonly) NSUInteger sentBytes;
@property(assign, nonatomic, readonly) NSUInteger receivedBytes;

@property(strong, nonatomic, readonly) NSError* error;
@property(assign, nonatomic, readonly, getter = wasSuccessfullyExecuted) BOOL successfullyExecuted;
@property(strong, nonatomic, readonly) BBHTTPResponse* response;
@property(assign, nonatomic, readonly) NSUInteger responseStatusCode;
@property(assign, nonatomic, readonly, getter = hasSuccessfulResponse) BOOL successfulResponse;


#pragma mark Cancelling a request

/// --------------------------
/// @name Cancelling a request
/// --------------------------

/**
 Immediately cancel this request.

 If the request has not been started, it will be discarded as soon as it hits the head of the queue of the
 `<BBHTTPExecutor>` in which it will be run
 */
- (BOOL)cancel;

/** Flag that indicates whether this request was cancelled. */
@property(assign, nonatomic, readonly, getter = wasCancelled) BOOL cancelled;

@end
