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

#import "BBHTTPAccumulator.h"

/**
 Simple response parser that extends `<BBHTTPAccumulator>` and converts the resulting `NSData` into a `NSString`.
 */
@interface BBHTTPToStringConverter : BBHTTPAccumulator


#pragma mark BBHTTPAccumulator behavior overrides

/**
 Converts the body of the response to a UTF8 `NSString`
 
 @param error On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error object
 containing the error information. You may specify nil for this parameter if you do not want the error information.

 @return UTF8 encoded string built from the body of the response.
 */
- (NSString*)parseContent:(NSError**)error;

@end
