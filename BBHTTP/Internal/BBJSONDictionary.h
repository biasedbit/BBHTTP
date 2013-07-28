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
 Surrogate for `NSDictionary` that makes the subscript operator call `valueForKeyPath:` on the wrapped dictionary
 &mdash; instead of the default behavior, which is to call `valueForKey:` &mdash; and forwards every other invocation.
 */
@interface BBJSONDictionary : NSObject


#pragma mark Creating a surrogate

///---------------------------
/// @name Creating a surrogate
///---------------------------

/**
 Creates a new dictionary surrogate for the given dictionary.
 
 @param dictionary Dictionary to wrap.
 
 @return A surrogate for the dictionary.
 */
- (instancetype)initWithDictionary:(NSDictionary*)dictionary;


#pragma mark NSDictionary behavior override

///-------------------------------------
/// @name NSDictionary behavior override
///-------------------------------------

/**
 Calls `valueForKeyPath:` on the underlying dictionary.
 
 @param key Keypath expression to apply to the underlying dictionary.
 
 @return Value for the given keypath expression.
 */
- (id)objectForKeyedSubscript:(NSString*)key;

@end
