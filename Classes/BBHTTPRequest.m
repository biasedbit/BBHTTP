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

#import "BBHTTPRequest.h"

#import "BBHTTPUtils.h"



#pragma mark - Constants

NSString* const kBBHTTPRequestDefaultUserAgentString = @"BBHotpotato/1.0";


#pragma mark -

@implementation BBHTTPRequest
{
    NSUInteger _uploadSize; // Cached upload size, when available
    NSMutableDictionary* _headers; // Header storage; auto generated synthesizer for headers property will use this ivar
}


#pragma mark Creating a request

- (id)init
{
    NSAssert(NO, @"please use initWithURL:andVerb: instead");
    return [self initWithTarget:@"http://biasedbit.com" andVerb:@"GET"];
}

- (id)initWithTarget:(NSString*)url andVerb:(NSString*)verb
{
    return [self initWithURL:[NSURL URLWithString:url] andVerb:verb];
}

- (id)initWithURL:(NSURL*)url andVerb:(NSString*)verb
{
    return [self initWithURL:url verb:verb andProtocolVersion:BBHTTPProtocolVersion_1_1];
}

- (id)initWithURL:(NSURL*)url verb:(NSString*)verb andProtocolVersion:(BBHTTPProtocolVersion)version;
{
    NSParameterAssert(![url isFileReferenceURL]);
    BBHTTPEnsureNotNil(url);
    BBHTTPEnsureNotNil(verb);

    self = [super init];
    if (self != nil) {
        _url = [url copy];
        _verb = [verb copy];
        _headers = [NSMutableDictionary dictionary];

        _startTimestamp = -1;
        _endTimestamp = -1;
        _version = version;
        _maxRedirects = 0;
        _allowInvalidSSLCertificates = NO;
        _discardBodyForNon200Responses = YES;
        _connectionTimeout = 10;
        _responseReadTimeout = 10;

        NSString* hostHeaderValue = [_url host];
        NSUInteger port = [self port];
        if (port != 80) hostHeaderValue = [hostHeaderValue stringByAppendingFormat:@":%ld", (long)port];

        [self setValue:hostHeaderValue forHeader:H(Host)];
        [self setValue:@"*/*" forHeader:H(Accept)];

        BBHTTPCreateSingleton(appName, NSString*,
                           [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleExecutableKey]);
        BBHTTPCreateSingleton(appVersion, NSString*,
                              [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]);

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
        BBHTTPCreateSingleton(model, NSString*, [[UIDevice currentDevice] model]);
        BBHTTPCreateSingleton(systemVersion, NSString*, [[UIDevice currentDevice] systemVersion]);
        NSString* userAgentString = [NSString stringWithFormat:@"BBHotpotato/%@ %@/%@ (%@; iOS %@; Scale/%0.2f)",
                                     BBHTTPVersion, appName, appVersion, model, systemVersion,
                                     [[UIScreen mainScreen] scale]];

#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
        // untested branch...
        NSString* osVersion = [[NSProcessInfo processInfo] operatingSystemVersionString];
        NSString* userAgentString = [NSString stringWithFormat:@"BBHotpotato/%@ %@/%@ (Mac OS X %@)",
                                     BBHTTPVersion, appName, appVersion, osVersion];

#endif
         [self setValue:userAgentString forHeader:H(UserAgent)];
    }

    return self;
}


#pragma mark Managing download behavior

- (NSUInteger)downloadSize
{
    return _response == nil ? 0 : _response.contentSize;
}

- (double)downloadProgress
{
    NSUInteger toReceive = self.downloadSize;
    if (toReceive == 0) return 0;

    return (self.receivedBytes / (double)self.downloadSize) * 100;
}

- (double)downloadTransferRate
{
    if (![self hasStarted]) return 0;

    NSUInteger toReceive = self.downloadSize;
    if (toReceive == 0) return 0;

    long long end = (self.endTimestamp > 0 ? self.endTimestamp : BBHTTPCurrentTimeMillis());
    return (self.receivedBytes * 1000) / (double)(end - self.startTimestamp);
}


#pragma mark Managing upload behavior

- (BOOL)setUploadStream:(NSInputStream*)stream withContentType:(NSString*)contentType andSize:(NSUInteger)size;
{
    BBHTTPEnsureNotNil(stream);
    BBHTTPEnsureNotNil(contentType);

    if (_version != BBHTTPProtocolVersion_1_1) return NO;

    _uploadFile = nil;
    _uploadData = nil;

    _uploadStream = stream;
    _uploadSize = size;

    [self setValue:contentType forHeader:H(ContentType)];
    if (size > 0) [self setValue:[NSString stringWithFormat:@"%lu", (long)size] forHeader:H(ContentLength)];

    return YES;
}

- (BOOL)setUploadFile:(NSString*)path
{
    return [self setUploadFile:path error:nil];
}

- (BOOL)setUploadFile:(NSString*)path error:(NSError**)error
{
    BBHTTPEnsureNotNil(path);

    NSError* err = nil;
    NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&err];
    if (err != nil) {
        if (error != NULL) *error = err;
        BBHTTPLogError(@"Can't read file attributes: %@", [err localizedDescription]);
        return NO;
    }

    unsigned long long size = [attributes fileSize];
    if (size == 0) {
        if (error != NULL) *error = BBHTTPCreateNSError(-1, @"File is empty (0 bytes)");
        BBHTTPLogError(@"File is empty (0 bytes)");
        return NO;
    } else if (size > NSUIntegerMax) {
        // This can probably be relaxed...
        BBHTTPLogError(@"File is too large (>%lu bytes)", NSUIntegerMax);
        if (error != NULL) *error = BBHTTPCreateNSErrorWithFormat(-2, @"File is too large (>%lu bytes)", NSUIntegerMax);
        return NO;
    }

    [self setValue:BBHTTPMimeType(path) forHeader:H(ContentType)];
    [self setValue:[NSString stringWithFormat:@"%llu", size] forHeader:H(ContentLength)];

    _uploadData = nil;
    _uploadStream = nil;

    _uploadSize = (NSUInteger)size;
    _uploadFile = [path copy];

    return YES;
}

- (BOOL)setUploadData:(NSData*)data withContentType:(NSString*)contentType
{
    BBHTTPEnsureNotNil(data);
    BBHTTPEnsureNotNil(contentType);

    if (data.length == 0) return NO;

    _uploadStream = nil;
    _uploadFile = nil;

    _uploadData = data;
    _uploadSize = [data length];

    [self setValue:contentType forHeader:H(ContentType)];
    [self setValue:[NSString stringWithFormat:@"%lu", (long)_uploadSize] forHeader:H(ContentLength)];

    return NO;
}

- (BOOL)isUpload
{
    return (_uploadData != nil) || (_uploadFile != nil) || (_uploadStream != nil);
}

- (BOOL)isUploadSizeKnown
{
    if ((_uploadStream != nil) && (_uploadSize == 0)) return NO;
    if ((_uploadFile != nil) || (_uploadData != nil)) return YES;
    else return NO;
}

- (double)uploadProgress
{
    NSUInteger toSend = self.uploadSize;
    if (toSend == 0) return 0;

    return (self.sentBytes / (double)toSend) * 100;
}

- (double)uploadTransferRate
{
    if (![self hasStarted]) return 0;

    NSUInteger toSend = self.uploadSize;
    if (toSend == 0) return 0;

    long long end = (self.endTimestamp > 0 ? self.endTimestamp : BBHTTPCurrentTimeMillis());
    return (self.sentBytes * 1000) / (double)(end - self.startTimestamp);
}


#pragma mark Manipulating headers

- (BOOL)hasHeader:(NSString*)header
{
    return _headers[header] != nil;
}

- (BOOL)hasHeader:(NSString*)header withValue:(NSString*)value
{
    NSString* headerValue = _headers[header];
    if (headerValue == nil) return NO;

    return [headerValue isEqualToString:value];
}

- (NSString*)headerWithName:(NSString*)header
{
    return _headers[header];
}

- (NSString*)objectForKeyedSubscript:(NSString*)header
{
    return _headers[header];
}

- (BOOL)setValue:(NSString*)value forHeader:(NSString*)header
{
    BBHTTPEnsureNotNil(value);
    BBHTTPEnsureNotNil(header);

    _headers[header] = value;

    return YES;
}

- (void)setObject:(NSString*)value forKeyedSubscript:(NSString*)header
{
    [self setValue:value forHeader:header];
}


#pragma mark Querying request properties

- (NSUInteger)port
{
    NSNumber* port = [_url port];
    BOOL isHttps = [[_url scheme] isEqualToString:@"https"];

    if (port == nil) return isHttps ? 443 : 80;
    else return [port unsignedIntValue];
}


#pragma mark Querying request state

- (BOOL)hasStarted
{
    return _startTimestamp > 0;
}

- (BOOL)hasFinished
{
    return _endTimestamp > 0;
}

- (BOOL)isExecuting
{
    return [self hasStarted] && ![self hasFinished];
}

- (BOOL)wasSuccessfullyExecuted
{
    return [self hasFinished] && (_response != nil);
}

- (NSUInteger)responseStatusCode
{
    return _response == nil ? 0 : _response.code;
}

- (BOOL)isSuccessfulResponse
{
    return [self wasSuccessfullyExecuted] && [_response isSuccessful];
}


#pragma mark Cancelling a request

- (BOOL)cancel
{
    if (_cancelled) return NO;

    _cancelled = YES;
    _endTimestamp = BBHTTPCurrentTimeMillis();

    return YES;
}


#pragma mark Debug

- (NSString*)description
{
    return [NSString stringWithFormat:@"%@ %@", _verb, _url];
}

@end
