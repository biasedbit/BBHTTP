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

#pragma mark -

/**
 Defines the interface for a response content handler.
 
 When a request is performed, its response content may be handled differently according to the implementation of the
 content handler it is configured to use.
 
 For instance, to handle JSON, the response content bytes would be read to a buffer and, when complete, that buffer
 would be converted to a JSON object.
 
 For examples of implementations of this protocol, take a look at `<BBHTTPAccumulator>` or `<BBHTTPFileWriter>`.
 */
@protocol BBHTTPContentHandler <NSObject>


@required

/**
 Prepares the response content handler for a response.
 
 If after inspecting the status code, message and headers the handler decides it does not want to accept the response,
 it should return `NO`.

 @param statusCode The response status code.
 @param message The response message from the response line (e.g. the "OK" in "200 OK" or
 "The Bees They're In My Eyes" in "500 The Bees They're In My Eyes").
 @param headers Dictionary with the response headers.
 @param error On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error object
 containing the error information. You may specify nil for this parameter if you do not want the error information.

 @return `YES` if this content handler accepts the response, `NO` otherwise.
 */
- (BOOL)prepareForResponse:(NSUInteger)statusCode message:(NSString*)message headers:(NSDictionary*)headers
                      error:(NSError**)error;
/**
 Feed response body data to the handler.
 
 If this method does not return the same number as the one it receives with the `length` parameter, the executor will
 assume error and abort the request.
 
 @param bytes Array of bytes.
 @param length Length of the byte array.
 @param error On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error object
 containing the error information. You may specify nil for this parameter if you do not want the error information.

 @return The number of bytes handled. If this number is inferior to `length`, the download will be aborted.
 */
- (NSInteger)appendResponseBytes:(uint8_t*)bytes withLength:(NSUInteger)length error:(NSError**)error;
- (id)parseContent:(NSError**)error;


@optional

/**
 Perform additional cleanup, if needed.
 */
- (void)cleanup;

@end
