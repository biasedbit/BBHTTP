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

#pragma mark - Constants

#define BBHTTPVersion @"0.9.1"



#pragma mark - Error codes

#define BBHTTPErrorCodeCancelled                     1000
#define BBHTTPErrorCodeUploadFileStreamError         1001
#define BBHTTPErrorCodeUploadDataStreamError         1002
#define BBHTTPErrorCodeDownloadCannotWriteToHandler  1003
#define BBHTTPErrorCodeUnnacceptableContentType      1004
#define BBHTTPErrorCodeImageDecodingFailed           1005



#pragma mark - Logging

#define BBHTTPLogLevelOff   0
#define BBHTTPLogLevelError 1
#define BBHTTPLogLevelWarn  2
#define BBHTTPLogLevelInfo  3
#define BBHTTPLogLevelDebug 4
#define BBHTTPLogLevelTrace 5

extern NSUInteger BBHTTPLogLevel;

extern void BBHTTPLog(NSUInteger level, NSString* prefix, NSString* format, ...) NS_FORMAT_FUNCTION(3, 4);

#define BBHTTPLogTrace(fmt, ...)  BBHTTPLog(5, @"TRACE", fmt, ##__VA_ARGS__);
#define BBHTTPLogDebug(fmt, ...)  BBHTTPLog(4, @"DEBUG", fmt, ##__VA_ARGS__);
#define BBHTTPLogInfo(fmt, ...)   BBHTTPLog(3, @" INFO", fmt, ##__VA_ARGS__);
#define BBHTTPLogWarn(fmt, ...)   BBHTTPLog(2, @" WARN", fmt, ##__VA_ARGS__);
#define BBHTTPLogError(fmt, ...)  BBHTTPLog(1, @"ERROR", fmt, ##__VA_ARGS__);



#pragma mark - DRY macros

#define BBHTTPCreateNSErrorWithFormat(c, fmt, ...) \
    [NSError errorWithDomain:@"com.biasedbit.hotpotato" code:c \
                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:fmt, ##__VA_ARGS__]}]

// We need two variants because passing a non-statically initialized NSString* instance as fmt will raise warning
// (becase we could be passing a ton of unmatched %@'s which would cause NSString to start reading from god-knows-where
// in memory and wreak havoc).
#define BBHTTPCreateNSError(c, description) \
    [NSError errorWithDomain:@"com.biasedbit.hotpotato" code:c \
                    userInfo:@{NSLocalizedDescriptionKey: description}]

#define BBHTTPCreateNSErrorWithReason(c, description, reason) \
    [NSError errorWithDomain:@"com.biasedbit.hotpotato" code:c \
                    userInfo:@{NSLocalizedDescriptionKey: description, NSLocalizedFailureReasonErrorKey: reason}]

#define BBHTTPEnsureNotNil(value) NSAssert((value) != nil, @"%s cannot be nil", #value)

#define BBHTTPEnsureSuccessOrReturn0(condition) do { if (!(condition)) return 0; } while(0)

#define BBHTTPCreateSingleton(name, type, value) \
    static type name; \
    if ((name) == nil) { \
        static dispatch_once_t name ## _token; \
        dispatch_once(&name##_token, ^{ name = (value); }); \
    }

#define BBHTTPCreateSingletonBlock(name, type, block) \
    static type name; \
    if ((name) == nil) { \
        static dispatch_once_t name ## _token; \
        dispatch_once(&name##_token, block); \
    }

#define BBHTTPHeaderName(name, override) static NSString* const BBHTTPHeaderName_##name = (override);
#define BBHTTPHeaderValue(value, override) static NSString* const BBHTTPHeaderValue_##value = (override);
#define H(name) BBHTTPHeaderName_##name
#define HV(value) BBHTTPHeaderValue_##value



#pragma mark - Headers names

BBHTTPHeaderName(Host,              @"Host") // Will create BBHTTPHeaderName_Host
BBHTTPHeaderName(UserAgent,         @"User-Agent")
BBHTTPHeaderName(ContentType,       @"Content-Type")
BBHTTPHeaderName(ContentLength,     @"Content-Length")
BBHTTPHeaderName(Accept,            @"Accept")
BBHTTPHeaderName(AcceptLanguage,    @"Accept-Language")
BBHTTPHeaderName(Expect,            @"Expect")
BBHTTPHeaderName(TransferEncoding,  @"Transfer-Encoding")
BBHTTPHeaderName(Date,              @"Date")
BBHTTPHeaderName(Authorization,     @"Authorization")



#pragma mark - Header values

BBHTTPHeaderValue(100Continue,   @"100-Continue") // Will create BBHTTPHeaderValue_100Continue
BBHTTPHeaderValue(Chunked,       @"chunked");



#pragma mark - Utility functions

extern NSString* BBHTTPMimeType(NSString* file);
extern long long BBHTTPCurrentTimeMillis(void);
