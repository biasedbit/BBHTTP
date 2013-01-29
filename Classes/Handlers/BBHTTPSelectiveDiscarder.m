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

#import "BBHTTPSelectiveDiscarder.h"

#import "BBHTTPUtils.h"



#pragma mark -

@implementation BBHTTPSelectiveDiscarder


#pragma mark Creation

- (id)init
{
    self = [super init];
    if (self != nil) {
        _acceptableResponses = @[@200, @201, @202, @203, @204];
        _acceptableContentTypes = nil; // accept everything
    }

    return self;
}


#pragma mark BBHTTPContentHandler

- (BOOL)prepareWithResponse:(NSUInteger)statusCode message:(NSString*)message headers:(NSDictionary*)headers
                      error:(NSError**)error
{
    if (![self isAcceptableResponseCode:statusCode]) {
        if (error != NULL) {
            *error = BBHTTPCreateNSErrorWithFormat(statusCode, @"Unnacceptable response: %lu %@",
                                                   (unsigned long)statusCode, message);
        }
        return NO;
    }

    NSString* contentType = headers[H(ContentType)]; // might be nil
    if (![self isAcceptableContentType:contentType]) {
        if (error != NULL) {
            *error = BBHTTPCreateNSError(BBHTTPErrorCodeUnnacceptableContentType,
                                         [@"Unnacceptable response content: " stringByAppendingString:contentType]);
        }
        return NO;
    }

    return YES;
}

- (NSInteger)appendResponseBytes:(uint8_t*)bytes withLength:(NSUInteger)length error:(NSError**)error
{
    return length;
}

- (id)parseContent:(NSError**)error
{
    return nil;
}


#pragma mark Obtaining the singleton

+ (instancetype)sharedDiscarder
{
    BBHTTPSingleton(BBHTTPSelectiveDiscarder, instance, [[BBHTTPSelectiveDiscarder alloc] init]);
    return instance;
}


#pragma mark Determining eligibility for content parsing (for subclasses)

- (BOOL)isAcceptableResponseCode:(NSUInteger)statusCode
{
    // When no acceptable response codes are defined, accept everything
    if ((_acceptableResponses == nil) || ([_acceptableResponses count] == 0)) return YES;

    NSNumber* wrappedResponseCode = [NSNumber numberWithUnsignedInteger:statusCode];
    return [_acceptableResponses containsObject:wrappedResponseCode];
}

- (BOOL)isAcceptableContentType:(NSString*)contentType
{
    if (contentType == nil) return NO; // Reject responses without content type header

    // When no acceptable response content types are defined, accept everything
    if ((_acceptableContentTypes == nil) || ([_acceptableContentTypes count] == 0)) return YES;

    // Go through each of the acceptable content types and return when first is matched.
    // For the time being, parameterized content types are not supported.
    for (NSString* acceptableContentType in _acceptableContentTypes) {
        NSRange searchResult = [contentType rangeOfString:acceptableContentType options:NSCaseInsensitiveSearch];
        if (searchResult.location != NSNotFound) return YES;
    }

    return NO;
}


#pragma mark Debug

- (NSString *)description
{
    return NSStringFromClass([self class]);
}

@end
