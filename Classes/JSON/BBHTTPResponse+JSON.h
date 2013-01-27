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



#pragma mark -

/**
 Adds JSON helpers to `BBHTTPResponse`.
 */
@interface BBHTTPResponse (JSON)


#pragma mark Convert response to JSON

///------------------------------------
/// @name Convert response data to JSON
///------------------------------------

/**
 Convert the response body into a JSON object.

 This method (blindly) attempts to convert the `NSData` at `<data>` to its object representation via
 `NSJSONSerialization`'s `JSONObjectWithData:options:error:` class method. It does not take into account the
 response status code nor the the announced content type.
 
 If the result of the JSON deserialization returns a `NSDictionary`, this method will wrap that dictionary in a
 `<BBJSONDictionary>`, to allow the usage of the keyed subscript operator as `valueForKeyPath:` instead of
 `valueForKey:`.
 
     id json = [response bodyAsJSON:nil];
     NSString* email = response[@"user.email"];
     NSNumber* followerCount = response[@"user.followers.@count"];

 Beware that only the top level object will be an instance of `<BBJSONDictionary>`. Dictionaries on other levels will
 be regular instances of `NSDictionary`:
 
     id json = [response bodyAsJSON:nil];           // json is a BBJSONDictionary
     id firstItem = json[@"list"][0];               // firstItem is a NSDictionary
     NSString* email = firstItem[@"user.email"];    // This will not work!
 
 > **Note:**
 > Currently, this method only returns an object if the body was downloaded to memory.
 
 @param error On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error object
 containing the error information. You may specify nil for this parameter if you do not want the error information.

 @return An object with the JSON representation of the response body or `nil` if either the response is empty or
 conversion fails &mdash; the latter will also set `error`.
 */
- (id)bodyAsJSON:(NSError**)error;

@end
