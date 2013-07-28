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

#import "BBHTTPRequest+Convenience.h"

#import "BBHTTPAccumulator.h"
#import "BBHTTPToStringConverter.h"
#import "BBJSONParser.h"
#import "BBHTTPImageDecoder.h"
#import "BBHTTPFileWriter.h"
#import "BBHTTPStreamWriter.h"
#import "BBHTTPExecutor.h"



#pragma mark -

@implementation BBHTTPRequest (Convenience)


#pragma mark      Create (POST)

+ (instancetype)createResource:(NSString*)resourceUrl withData:(NSData*)data contentType:(NSString*)contentType
{
    return [self postToURL:[NSURL URLWithString:resourceUrl] data:data contentType:contentType];
}

+ (instancetype)postToURL:(NSURL*)url data:(NSData*)data contentType:(NSString*)contentType
{
    BBHTTPRequest* request = [[self alloc] initWithURL:url andVerb:@"POST"];
    [request setUploadData:data withContentType:contentType];

    return request;
}

+ (instancetype)createResource:(NSString*)resourceUrl withContentsOfFile:(NSString*)pathToFile
{
    return [self postToURL:[NSURL URLWithString:resourceUrl] withContentsOfFile:pathToFile];
}

+ (instancetype)postToURL:(NSURL*)url withContentsOfFile:(NSString*)pathToFile
{
    BBHTTPRequest* request = [[BBHTTPRequest alloc] initWithURL:url andVerb:@"POST"];
    if (![request setUploadFile:pathToFile error:nil]) return nil;

    return request;
}

#pragma mark      Read (GET)

+ (instancetype)readResource:(NSString*)resourceUrl
{
    return [self getFromURL:[NSURL URLWithString:resourceUrl]];
}

+ (instancetype)getFromURL:(NSURL*)url
{
    return [[self alloc] initWithURL:url andVerb:@"GET"];
}

#pragma mark      Update (PUT)

+ (instancetype)updateResource:(NSString*)resourceUrl withData:(NSData*)data contentType:(NSString*)contentType
{
    return [self putToURL:[NSURL URLWithString:resourceUrl] data:data contentType:contentType];
}

+ (instancetype)putToURL:(NSURL*)url data:(NSData*)data contentType:(NSString*)contentType
{
    BBHTTPRequest* request = [[self alloc] initWithURL:url andVerb:@"PUT"];
    [request setUploadData:data withContentType:contentType];

    return request;
}

+ (instancetype)updateResource:(NSString*)resourceUrl withContentsOfFile:(NSString*)pathToFile
{
    return [self putToURL:[NSURL URLWithString:resourceUrl] withContentsOfFile:pathToFile];
}

+ (instancetype)putToURL:(NSURL*)url withContentsOfFile:(NSString*)pathToFile
{
    BBHTTPRequest* request = [[BBHTTPRequest alloc] initWithURL:url andVerb:@"PUT"];
    if (![request setUploadFile:pathToFile error:nil]) return nil;

    return request;
}

#pragma mark      Delete (DELETE)

+ (instancetype)deleteResource:(NSString*)resourceUrl
{
    return [self deleteAtURL:[NSURL URLWithString:resourceUrl]];
}

+ (instancetype)deleteAtURL:(NSURL*)url
{
    return [[self alloc] initWithURL:url andVerb:@"DELETE"];
}


#pragma mark Configuring response content handling

- (void)downloadContentAsData
{
    self.responseContentHandler = [[BBHTTPAccumulator alloc] init];
}

- (void)downloadContentAsString
{
    self.responseContentHandler = [[BBHTTPToStringConverter alloc] init];
}

- (void)downloadContentAsStringWithEncoding:(NSStringEncoding)encoding
{
    self.responseContentHandler = [[BBHTTPToStringConverter alloc] initWithEncoding:encoding];
}

- (void)downloadContentAsJSON
{
    self.responseContentHandler = [[BBJSONParser alloc] init];
}

- (void)downloadContentAsImage
{
    self.responseContentHandler = [[BBHTTPImageDecoder alloc] init];
}

- (void)downloadToFile:(NSString*)pathToFile
{
    self.responseContentHandler = [[BBHTTPFileWriter alloc] initWithTargetFile:pathToFile];
}

- (void)downloadToStream:(NSOutputStream*)stream
{
    self.responseContentHandler = [[BBHTTPStreamWriter alloc] initWithOutputStream:stream];
}

- (void)discardResponseContent
{
    self.responseContentHandler = [BBHTTPSelectiveDiscarder sharedDiscarder];
}

- (instancetype)asData
{
    [self downloadContentAsData];

    return self;
}

- (instancetype)asString
{
    [self downloadContentAsString];

    return self;
}

- (instancetype)asStringWithEncoding:(NSStringEncoding)encoding
{
    [self downloadContentAsStringWithEncoding:encoding];

    return self;
}

- (instancetype)asJSON
{
    [self downloadContentAsJSON];

    return self;
}

- (instancetype)asImage
{
    [self downloadContentAsImage];

    return self;
}


#pragma mark Executing the request

- (BOOL)execute:(void (^)(BBHTTPRequest* request))finish
{
    self.finishBlock = finish;

    return [[BBHTTPExecutor sharedExecutor] executeRequest:self];
}

- (BOOL)execute:(void (^)(BBHTTPResponse* response))completed error:(void (^)(NSError* error))error
{
    return [self execute:completed error:error cancelled:nil finally:nil];
}

- (BOOL)execute:(void (^)(BBHTTPResponse* response))completed error:(void (^)(NSError* error))error
        finally:(void (^)())finally
{
    return [self execute:completed error:error cancelled:nil finally:finally];
}

- (BOOL)execute:(void (^)(BBHTTPResponse* response))completed error:(void (^)(NSError* error))error
      cancelled:(void (^)())cancelled finally:(void (^)())finally
{
    // If nothing was specified, load body to memory -- perhaps an instance of BBHTTPDiscard would be better here?
    if (self.responseContentHandler == nil) [self downloadContentAsData];

    self.finishBlock = ^(BBHTTPRequest* request) {
        if (request.error != nil) {
            if (error != nil) error(request.error);
        } else if ([request wasCancelled]) {
            if (cancelled != nil) cancelled();
        } else {
            if (completed != nil) completed(request.response);
        }

        if (finally != nil) finally();
    };

    return [[BBHTTPExecutor sharedExecutor] executeRequest:self];
}

- (BOOL)setup:(void (^)(BBHTTPRequest* request))setup execute:(void (^)(BBHTTPResponse* response))completed
        error:(void (^)(NSError* error))error
{
    if (setup != nil) setup(self);

    return [self execute:completed error:error cancelled:nil finally:nil];
}

- (BOOL)setup:(void (^)(BBHTTPRequest* request))setup execute:(void (^)(BBHTTPResponse* response))completed
        error:(void (^)(NSError* error))error finally:(void (^)())finally
{
    if (setup != nil) setup(self);

    return [self execute:completed error:error cancelled:nil finally:finally];
}

- (BOOL)setup:(void (^)(BBHTTPRequest* request))setup execute:(void (^)(BBHTTPResponse* response))completed
        error:(void (^)(NSError* error))error cancelled:(void (^)())cancelled finally:(void (^)())finally
{
    if (setup != nil) setup(self);

    return [self execute:completed error:error cancelled:cancelled finally:finally];
}

@end
