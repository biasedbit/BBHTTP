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

#import "BBJSONDictionary.h"



#pragma mark -

@implementation BBJSONDictionary
{
    NSDictionary* _dictionary;
}

#pragma mark Creating a surrogate

- (instancetype)initWithDictionary:(NSDictionary*)dictionary
{
    self = [super init];
    if (self != nil) _dictionary = dictionary;

    return self;
}


#pragma mark NSDictionary behavior override

- (id)objectForKeyedSubscript:(NSString*)key
{
    return [_dictionary valueForKeyPath:key];
}

- (id)forwardingTargetForSelector:(SEL)selector
{
    // Docs state that forwardingTargetForSelector "(...) can be an order of magnitude faster than regular forwarding."
    if ([_dictionary respondsToSelector:selector]) return _dictionary;
    return nil;
}

- (NSString*)description
{
    return [_dictionary description];
}

@end
