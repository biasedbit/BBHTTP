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

#import "BBHTTPResponse+JSON.h"

#import "BBJSONDictionary.h"



#pragma mark -

@implementation BBHTTPResponse (JSON)


#pragma mark Convert response to JSON

- (id)bodyAsJSON:(NSError**)error
{
    if (self.contentSize == 0) return nil;

    // TODO also read from file/output stream?
    id result = [NSJSONSerialization JSONObjectWithData:self.data options:0 error:error];

    if (((error != NULL) && (*error != nil)) || (result == nil)) return nil;

    // If it's a dictionary, wrap it in BBHTTPDictionary; allows keypath retrieval via subscript operators.
    if ([result isKindOfClass:[NSDictionary class]]) return [[BBJSONDictionary alloc] initWithDictionary:result];
    else return result;
}

@end
