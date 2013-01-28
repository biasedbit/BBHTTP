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

#import "BBHTTPContentHandler.h"



#pragma mark -

/**
 Abstract class that includes logic to accept or reject requests, based on their response status code and content type
 headers.
 */
@interface BBHTTPSelectiveHandler : NSObject <BBHTTPContentHandler>


#pragma mark Defining response pre-conditions for content parsing

///-----------------------------------------------------------
/// @name Defining response pre-conditions for content parsing
///-----------------------------------------------------------

/**
 List of response codes considered acceptable for a response, in order for content parsing to be allowed.

 You must pass a `NSArray` containing only `NSNumber` instances:

 [request setAcceptableResponses:@[@200, @201, @202]];

 Setting this property to `nil` or to an empty array will cause all response codes to be accepted.
 */
@property(copy, nonatomic) NSArray* acceptableResponses;

/**
 List of MIME types considered acceptable for the `Content-Type` header of a response, in order for content parsing
 to be allowed.

 Each string you provide will be tested, in order, against the response's `Content-Type` &mdash; it is therefore a good
 idea to place common types first.

 For the time being, this implementation does a dumb substring search so if you want wildcard matching, just use parts
 of the string.

 Examples:

 * `application/json` would allow `application/json;encoding=utf-8`
 * `application/json;encoding=utf-8` would not allow `application/json`
 * `text/` would allow any content type beginning with "text/"
 * `json` would allow any content type containing "json"

 Setting this property to `nil` or to an empty array will cause any content type to be accepted.
 */
@property(copy, nonatomic) NSArray* acceptableContentTypes;


#pragma mark Determining eligibility for content parsing (for subclasses)

- (BOOL)isAcceptableResponseCode:(NSUInteger)statusCode;
- (BOOL)isAcceptableContentType:(NSString*)contentType;

@end
