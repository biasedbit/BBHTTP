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

#import "BBJSONRequest.h"

#import "BBHTTPRequest+Convenience.h"
#import "BBHTTPUtils.h"



#pragma mark -

@implementation BBJSONRequest

static NSArray* _DefaultAcceptableResponses;
static NSArray* _DefaultAcceptableContentTypes;


#pragma mark Class creation

+ (void)initialize
{
    _DefaultAcceptableResponses = @[@200, @201];
    _DefaultAcceptableContentTypes = @[@"application/json"];
}


#pragma mark Creation

- (id)initWithURL:(NSURL *)url verb:(NSString *)verb andProtocolVersion:(BBHTTPProtocolVersion)version
{
    self = [super initWithURL:url verb:verb andProtocolVersion:version];
    if (self != nil) {
        _acceptableResponses = _DefaultAcceptableResponses;
        _acceptableContentTypes = _DefaultAcceptableContentTypes;
    }

    return self;
}


#pragma mark Defining response pre-conditions for JSON parsing

- (void)setAcceptableResponseCodes:(NSArray*)acceptableResponseCodes
{
    _acceptableResponses = [acceptableResponseCodes copy];
}

- (void)setAcceptableContentTypes:(NSArray*)acceptableContentTypes
{
    _acceptableContentTypes = [acceptableContentTypes copy];
}

+ (void)setDefaultAcceptableResponses:(NSArray*)acceptableResponseCodes
{
    _DefaultAcceptableResponses = [acceptableResponseCodes copy];
}

+ (void)setDefaultAcceptableContentTypes:(NSArray*)acceptableContentTypes
{
    _DefaultAcceptableContentTypes = [acceptableContentTypes copy];
}


#pragma mark Retrieving JSON object

- (id)convertResponseBodyToJSON:(NSError**)error
{
    if (![super hasSuccessfulResponse]) return nil; // call super because self's has been overridden

    if (![self hasAcceptableResponseCode]) {
        if (error != NULL) {
            NSString* message = [NSString stringWithFormat:@"Unnacceptable response received from server: %lu %@",
                                 (unsigned long)self.response.code, self.response.message];
            *error = BBHTTPCreateNSError(self.response.code, message);
        }
        return nil;
    }

    if (![self hasAcceptableResponseContentType]) {
        if (error != NULL) {
            NSString* contentType = self.response[H(ContentType)];
            NSString* message = [@"Unnacceptable content type in response: " stringByAppendingString:contentType];
            *error = BBHTTPCreateNSError(BBHTTPErrorCodeInvalidJSONContentType, message);
        }
        return nil;
    }

    return [self.response bodyAsJSON:error];
}


#pragma mark Execution shortcuts

- (BOOL)getJSON:(void (^)(id result))success error:(void (^)(NSError* error))error
{
    return [self setup:nil getJSON:success error:error finally:nil];
}

- (BOOL)getJSON:(void (^)(id result))success error:(void (^)(NSError* error))error finally:(void (^)())finally
{
    return [self setup:nil getJSON:success error:error finally:finally];
}

- (BOOL)setup:(void (^)(id request))setup getJSON:(void (^)(id result))success error:(void (^)(NSError* error))error
{
    return [self setup:setup getJSON:success error:error finally:nil];
}

- (BOOL)setup:(void (^)(id request))setup getJSON:(void (^)(id result))success
        error:(void (^)(NSError* error))error finally:(void (^)())finally
{
    return [self setup:setup execute:^(BBHTTPResponse* response) {
        NSError* e = nil;
        id json = [self convertResponseBodyToJSON:&e];

        if (e != nil) {
            if (error != nil) error(e);
        } else {
            if (success != nil) success(json);
        }
    } error:error finally:finally];
}


#pragma mark BBHTTPRequest behavior overrides

- (void)setDownloadToFile:(NSString*)downloadToFile
{
    NSAssert(NO, @"For the time being, BBJSONRequest can only receive data to memory.");
}

- (void)setDownloadToStream:(NSOutputStream*)downloadToStream
{
    NSAssert(NO, @"For the time being, BBJSONRequest can only receive data to memory.");
}

- (BOOL)hasSuccessfulResponse
{
    return [self hasAcceptableResponseCode];
}


#pragma mark Private helpers

- (BOOL)hasAcceptableResponseCode
{
    // When no acceptable response codes are defined, reject everything
    if ((_acceptableResponses == nil) || ([_acceptableResponses count] == 0)) return NO;

    NSNumber* wrappedResponseCode = [NSNumber numberWithUnsignedInteger:self.response.code];
    return [_acceptableResponses containsObject:wrappedResponseCode];
}

- (BOOL)hasAcceptableResponseContentType
{
    // When no acceptable response content types are defined, reject everything
    if ((_acceptableContentTypes == nil) || ([_acceptableContentTypes count] == 0)) return NO;

    NSString* contentType = self.response[H(ContentType)];
    if (contentType == nil) return NO; // Reject responses without content type header

    // Go through each of the acceptable content types and return when first is matched.
    // For the time being, parameterized content types are not supported.
    for (NSString* acceptableContentType in _acceptableContentTypes) {
        NSRange searchResult = [contentType rangeOfString:acceptableContentType options:NSCaseInsensitiveSearch];
        if (searchResult.location != NSNotFound) return YES;
    }

    return NO;
}

@end
