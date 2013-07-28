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

#import "BBJSONParser.h"

#import "BBJSONDictionary.h"



#pragma mark -

@implementation BBJSONParser

static NSArray* _DefaultAcceptableResponses;
static NSArray* _DefaultAcceptableContentTypes;


#pragma mark Class creation

+ (void)initialize
{
    _DefaultAcceptableResponses = @[@200, @201, @202, @203];
    _DefaultAcceptableContentTypes = @[@"application/json"];
}


#pragma mark Creation

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        self.acceptableResponses = _DefaultAcceptableResponses;
        self.acceptableContentTypes = _DefaultAcceptableContentTypes;
    }

    return self;
}


#pragma mark Defining response pre-conditions for JSON parsing

+ (void)setDefaultAcceptableResponses:(NSArray*)acceptableResponseCodes
{
    _DefaultAcceptableResponses = [acceptableResponseCodes copy];
}

+ (void)setDefaultAcceptableContentTypes:(NSArray*)acceptableContentTypes
{
    _DefaultAcceptableContentTypes = [acceptableContentTypes copy];
}


#pragma mark BBHTTPAccumulator behavior override

- (id)parseContent:(NSError**)error
{
    // super ensures we have a valid response code and a valid content type
    NSData* data = [super parseContent:error];
    if (((error != NULL) && (*error != nil)) || (data == nil)) return nil;

    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (((error != NULL) && (*error != nil)) || (json == nil)) return data;

    // If it's a dictionary, wrap it in BBHTTPDictionary; allows keypath retrieval via subscript operators.
    if ([json isKindOfClass:[NSDictionary class]]) return [[BBJSONDictionary alloc] initWithDictionary:json];
    else return json;
}

@end
