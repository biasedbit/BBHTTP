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

#import "BBHTTPRequest+Convenience.h"

#import "BBHTTPExecutor.h"



#pragma mark -

@implementation BBHTTPRequest (Convenience)


#pragma mark Creating common requests

+ (instancetype)getFrom:(NSString*)url
{
    return [self getFromURL:[NSURL URLWithString:url]];
}

+ (instancetype)getFromURL:(NSURL*)url
{
    return [[self alloc] initWithURL:url andVerb:@"GET"];
}

+ (instancetype)deleteAtURL:(NSURL*)url
{
    return [[self alloc] initWithURL:url andVerb:@"DELETE"];
}

+ (instancetype)postData:(NSData*)data withContentType:(NSString*)contentType to:(NSString*)url
{
    return [self postData:data withContentType:contentType toURL:[NSURL URLWithString:url]];
}

+ (instancetype)postData:(NSData*)data withContentType:(NSString*)contentType toURL:(NSURL*)url
{
    BBHTTPRequest* request = [[self alloc] initWithURL:url andVerb:@"POST"];
    [request setUploadData:data withContentType:contentType];

    return request;
}

+ (instancetype)putToURL:(NSURL*)url withData:(NSData*)data andContentType:(NSString*)contentType
{
    BBHTTPRequest* request = [[self alloc] initWithURL:url andVerb:@"PUT"];
    [request setUploadData:data withContentType:contentType];

    return request;
}

+ (instancetype)postFile:(NSString*)path to:(NSString*)url
{
    return [self postFile:path toURL:[NSURL URLWithString:url]];
}

+ (instancetype)postFile:(NSString*)path toURL:(NSURL*)url
{
    BBHTTPRequest* request = [[BBHTTPRequest alloc] initWithURL:url andVerb:@"POST"];
    if (![request setUploadFile:path]) return nil;

    return request;
}


#pragma mark Executing the request

- (BOOL)execute:(void (^)(BBHTTPResponse* response))finish error:(void (^)(NSError* error))error
{
    return [[BBHTTPExecutor sharedExecutor] executeRequest:self finish:finish error:error];
}

- (BOOL)setup:(void (^)(BBHTTPRequest* request))setup andExecute:(void (^)(BBHTTPResponse* response))finish
        error:(void (^)(NSError* error))error
{
    if (setup != nil) setup(self);
    return [self execute:finish error:error];
}

@end
