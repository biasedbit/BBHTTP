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

#import "BBHTTPRequest.h"



#pragma mark -

@interface BBHTTPRequest (Convenience)


#pragma mark Creating common requests

///-------------------------------
/// @name Creating common requests
///-------------------------------

#pragma mark      Create (POST)

/**
 Creates a `POST` request to the target url, with the contents of an in-memory buffer and a specified content-type.

 This method is a convenience shortcut to `<postData:withContentType:toURL:>` that takes a string as input and converts
 it to a `NSURL`.

 @see postDataToURL:data:contentType:
 */
+ (instancetype)createResource:(NSString*)resourceUrl withData:(NSData*)data contentType:(NSString*)contentType;

/**
 Creates a `POST` request to the target url, with the contents of an in-memory buffer and a specified content-type.

 This method is a convenience shortcut to creating a new request and then calling `setUploadData:withContentType:` on
 it. Be sure to refer to that method for further information.

 The generated request will respond `YES` to `isUpload` and `isUploadFromMemory`.

 @return A `POST` request to *url*, with the value of *contentType* set as the `Content-Type` header and the contents
 of data as the body. May return `nil` if *data* is invalid.

 @see initWithURL:andVerb:
 @see setUploadData:withContentType:
 */
+ (instancetype)postToURL:(NSURL*)url data:(NSData*)data contentType:(NSString*)contentType;
+ (instancetype)createResource:(NSString*)resourceUrl withContentsOfFile:(NSString*)pathToFile;
+ (instancetype)postToURL:(NSURL*)url withContentsOfFile:(NSString*)pathToFile;

#pragma mark      Read (GET)

/**
 Creates a `GET` request to the target url.

 This method is a convenience shortcut to `getFromURL:` that takes a string as input and converts it to a `NSURL`.

 @see getFromURL:
 */
+ (instancetype)readResource:(NSString*)resourceUrl;

/**
 Creates a `GET` request to the target url.

 @param url The target URL.

 @return A `GET` request to *url*.
 */
+ (instancetype)getFromURL:(NSURL*)url;

#pragma mark      Update (PUT)

+ (instancetype)updateResource:(NSString*)resourceUrl withData:(NSData*)data contentType:(NSString*)contentType;
+ (instancetype)putToURL:(NSURL*)url data:(NSData*)data contentType:(NSString*)contentType;
+ (instancetype)updateResource:(NSString*)resourceUrl withContentsOfFile:(NSString*)pathToFile;
+ (instancetype)putToURL:(NSURL*)url withContentsOfFile:(NSString*)pathToFile;


#pragma mark      Delete (DELETE)

+ (instancetype)deleteResource:(NSString*)resourceUrl;

/**
 Creates a `DELETE` request to the target url.

 @param url The target URL.

 @return A `DELETE` request to *url*.
 */
+ (instancetype)deleteAtURL:(NSURL*)url;


#pragma mark Configuring response content handling

/**
 Treat the reponse body as `NSData`.
 
 When a successful response is received, a `NSData` will be available at at the `content` property of the response.

 This method assigns a `<BBHTTPAccumulator>` as the `<responseContentHandler>` for this request.
 */
- (void)downloadContentAsData;

/**
 Treat the reponse body as a `NSString`
 
 When a successful response is received, a `NSString` will be available at at the `content` property of the response.

 This method assigns a `<BBHTTPToStringConverter>` as the `<responseContentHandler>` for this request.
 */
- (void)downloadContentAsString;

/**
 Treat the reponse body as JSON.
 
 When a successful response is received, the parsed JSON object will be available at the `content` property of the 
 response.

 This method assigns a `<BBJSONParser>` as the `<responseContentHandler>` for this request.
 */
- (void)downloadContentAsJSON;

/**
 Treat the reponse body as an image.

 When a successful response is received, the decoded `NSImage`/`UIImage` will be available at the `content` property of
 the response.

 This method assigns a `<BBHTTPImageDecoder>` as the `<responseContentHandler>` for this request.
 */
- (void)downloadContentAsImage;

/**
 Download the response body directo to a file.
 
 The `content` property of the response will be nil. If the download fails, any partially downloaded file is deleted.
 
 This method assigns a `<BBHTTPFileWriter>` as the `<responseContentHandler>` for this request.
 
 @param pathToFile Path to the file to write to.
 */
- (void)downloadToFile:(NSString*)pathToFile;

/**
 Download the response body directly to an output stream.

 The `content` property of the response will be nil. If the download fails, the stream will be closed.

 This method assigns a `<BBHTTPStreamWriter>` as the `<responseContentHandler>` for this request.
 
 @param stream The output stream to write to.
 */
- (void)downloadToStream:(NSOutputStream*)stream;

/**
 Completely discard any data received as the body of the response.

 Sets `<responseContentHandler>` to `<[BBHTTPSelectiveDiscarder sharedDiscarder]>`.
 */
- (void)discardResponseContent;

/**
 Fluent syntax shortcut for `<downloadContentAsData>`.
 
 @return The current instance.
 */
- (instancetype)asData;

/**
 Fluent syntax shortcut for `<downloadContentAsString>`.

 @return The current instance.
 */
- (instancetype)asString;

/**
 Fluent syntax shortcut for `<downloadContentAsJSON>`.

 @return The current instance.
 */
- (instancetype)asJSON;

/**
 Fluent syntax shortcut for `<downloadContentAsImage>`.

 @return The current instance.
 */
- (instancetype)asImage;


#pragma mark Executing the request

///----------------------------
/// @name Executing the request
///----------------------------

- (BOOL)execute:(void (^)(BBHTTPRequest* request))finish;

/**
 Convenience method that executes this request in the singleton instance of `<BBHTTPExecutor>`.

 @param finish The finish block that will be called when the request terminates normally.
 @param error The error block that will be called if the request terminates abnormally.

 @return `YES` if the request was accepted for execution by the executor, `NO` otherwise.

 @see BBHTTPExecutor
 */
- (BOOL)execute:(void (^)(BBHTTPResponse* response))completed error:(void (^)(NSError* error))error;

- (BOOL)execute:(void (^)(BBHTTPResponse* response))completed error:(void (^)(NSError* error))error
        finally:(void (^)())finally;

- (BOOL)execute:(void (^)(BBHTTPResponse* response))completed error:(void (^)(NSError* error))error
      cancelled:(void (^)())cancelled finally:(void (^)())finally;

/**
 Convenience method allows for extra request preparation steps and executes this request in the singleton instance of
 `<BBHTTPExecutor>`.

 @param setup The setup block, will be called passing the current request as argument. Allows you to perform
 additional setup on the request before it is fired into the network.
 @param finish The finish block that will be called when the request terminates normally.
 @param error The error block that will be called if the request terminates abnormally.

 @return `YES` if the request was accepted for execution by the executor, `NO` otherwise.

 @see BBHTTPExecutor
 */
- (BOOL)setup:(void (^)(BBHTTPRequest* request))setup execute:(void (^)(BBHTTPResponse* response))completed
        error:(void (^)(NSError* error))error;

- (BOOL)setup:(void (^)(BBHTTPRequest* request))setup execute:(void (^)(BBHTTPResponse* response))completed
        error:(void (^)(NSError* error))error finally:(void (^)())finally;

- (BOOL)setup:(void (^)(BBHTTPRequest* request))setup execute:(void (^)(BBHTTPResponse* response))completed
        error:(void (^)(NSError* error))error cancelled:(void (^)())cancelled finally:(void (^)())finally;

@end
