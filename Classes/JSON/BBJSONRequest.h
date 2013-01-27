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

#import "BBHTTPRequest.h"

#import "BBHTTPResponse+JSON.h"



#pragma mark -

@interface BBJSONRequest : BBHTTPRequest


#pragma mark Defining response pre-conditions for JSON parsing

///--------------------------------------------------------
/// @name Defining response pre-conditions for JSON parsing
///--------------------------------------------------------

/**
 List of response codes considered acceptable for a response, in order for JSON parsing to be allowed.
 
 You must pass a `NSArray` containing only `NSNumber` instances:
 
    [request setAcceptableResponses:@[@200, @201, @204]];
 
 The values in this property also affect `hasSuccessfulResponse`, thus overriding superclass behavior.
 
 Setting this property to `nil` or to an empty array will cause JSON parsing to fail.
 
 @see setDefaultAcceptableResponses:
 */
@property(copy, nonatomic) NSArray* acceptableResponses;

/**
 List of MIME types considered acceptable for the `Content-Type` header of a response, in order for JSON parsing
 to be allowed.

 Each content type string you provide will be tested, in order, against the response's `Content-Type` header when
 `<convertResponseBodyToJSON:>` is called &mdash; it is therefore a good idea to place common types first.
 
 For the time being, **content-type parameters are not supported**. That means the MIME type array you pass to this
 property must contain only non-parameterized MIME types, i.e. composed solely of `type` and `subtype`:
 
 * `application/json` is a simple MIME type.
 * `application/json; encoding=utf-8` is a parameterized MIME type and will cause JSON conversion to fail.

 Setting this property to `nil` or to an empty array will cause JSON parsing to fail.
 
 @see setDefaultAcceptableContentTypes:
 */
@property(copy, nonatomic) NSArray* acceptableContentTypes;

/**
 Affects the `<acceptableResponses>` property for every new instance of this class that is created.

 Use this method if the default acceptable response codes don't fit your needs, as to avoid having to set them up for
 every new request.
 
 @param acceptableResponses Array of numbers.
 
 @see acceptableResponses
 */
+ (void)setDefaultAcceptableResponses:(NSArray*)acceptableResponses;

/**
 Affects the `<acceptableContentTypes>` property for every new instance of this class that is created.
 
 Use this method if the default acceptable content types don't fit your needs, as to avoid having to set them up for
 every new request.

 @param acceptableContentTypes Array of strings.
 
 @see acceptableContentTypes
 */
+ (void)setDefaultAcceptableContentTypes:(NSArray*)acceptableContentTypes;


#pragma mark Retrieving JSON object

///-----------------------------
/// @name Retrieving JSON object
///-----------------------------

/**
 Convert request body to JSON object.
 
 This method will check if the response has a [valid response code](<acceptableResponses>) and a
 [valid content type](<acceptableContentTypes>) before delegating to `<[BBHTTPResponse bodyAsJSON:]>`.

 @param error On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error object
 containing the error information. You may specify nil for this parameter if you do not want the error information.

 @return An object with the JSON representation of the response body or `nil` if:
 
 * the response's status code doesn't match the status codes in `<acceptableResponses>` (sets `error`);
 * the response has no content type header (sets `error`);
 * the response has no body to be parsed;
 * the response's content type header doesn't match any of the types in `<acceptableContentTypes>` (sets `error`);
 * parsing fails (sets `error`).
 
 @see acceptableResponses
 @see acceptableContentTypes
 @see [BBHTTPResponse bodyAsJSON:]
 */
- (id)convertResponseBodyToJSON:(NSError**)error;


#pragma mark Execution shortcuts

///--------------------------
/// @name Execution shortcuts
///--------------------------

/**
 Shortcut to `<setup:getJSON:error:finally:>`, passing `nil` for both `setup` and `finally` blocks.
 
 @see getJSON:error:finally:
 @see setup:getJSON:error:
 @see setup:getJSON:error:finally:
 */
- (BOOL)getJSON:(void (^)(id result))success
          error:(void (^)(NSError* error))error;

/**
 Shortcut to `<setup:getJSON:error:finally:>`, passing `nil` for `setup` block.

 @see getJSON:error:
 @see setup:getJSON:error:
 @see setup:getJSON:error:finally:
 */
- (BOOL)getJSON:(void (^)(id result))success
          error:(void (^)(NSError* error))error
        finally:(void (^)())finally;

/**
 Shortcut to `<setup:getJSON:error:finally:>`, passing `nil` for `finally` block.

 @see getJSON:error:
 @see getJSON:error:finally:
 @see setup:getJSON:error:finally:
 */
- (BOOL)setup:(void (^)(id request))setup
      getJSON:(void (^)(id result))success
        error:(void (^)(NSError* error))error;

/**
 Shortcut for `<[BBHTTPRequest setup:execute:error:finally:]>` that creates a response handling block which will
 check if the response has a [valid response code](<acceptableResponses>) and [content type](<acceptableContentTypes>)
 before trying to parse response body as JSON.

 If the request fails, any of the request pre-conditions fail or if JSON parsing fails, the `error` block will be
 called. If JSON parsing succeeds, `success` block will be called with the resulting object.

 @param setup Setup block.
 @param success JSON decoding success block.
 @param error Error handling block.
 @param finally Block that executes after `success` or `error`.
 
 @return `YES` if the request submission to the default `<BBHTTPExecutor>` was successful, `NO` otherwise.
 
 @see convertResponseBodyToJSON:
 @see [BBHTTPResponse bodyAsJSON:]
 @see BBJSONDictionary
 */
- (BOOL)setup:(void (^)(id request))setup
      getJSON:(void (^)(id result))success
        error:(void (^)(NSError* error))error
      finally:(void (^)())finally;


#pragma mark BBHTTPRequest behavior overrides

///---------------------------------------
/// @name BBHTTPRequest behavior overrides
///---------------------------------------

/**
 Overrides property in superclass to flag whether the response has a valid status code, according to
 `<acceptableResponses>`.

 @return YES if the request has a response and its status code matches any of the codes in `<acceptableResponses>`.
 */
- (BOOL)hasSuccessfulResponse;

@end
