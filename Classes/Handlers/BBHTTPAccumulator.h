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

#import "BBHTTPSelectiveHandler.h"



#pragma mark -

@interface BBHTTPAccumulator : BBHTTPSelectiveHandler


#pragma mark BBHTTPResponseProcessor interface overrides

/**
 Convert request body to `NSData`.

 @param error On input, a pointer to an error object. If an error occurs, this pointer is set to an actual error object
 containing the error information. You may specify nil for this parameter if you do not want the error information.

 @return A `NSData` object containing the content of the response body or `nil` if body was empty.
 */
- (NSData*)parseContent:(NSError**)error;

@end
