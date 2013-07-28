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

#pragma mark - Constants

#define BBHTTPVersion @"0.9.8"



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

extern void BBHTTPLog(NSUInteger level, NSString* prefix, NSString* (^statement)());

#define BBHTTPLogError(fmt, ...)  BBHTTPLog(1, @"ERROR", ^{ return [NSString stringWithFormat:fmt, ##__VA_ARGS__]; });
#define BBHTTPLogWarn(fmt, ...)   BBHTTPLog(2, @" WARN", ^{ return [NSString stringWithFormat:fmt, ##__VA_ARGS__]; });
#define BBHTTPLogInfo(fmt, ...)   BBHTTPLog(3, @" INFO", ^{ return [NSString stringWithFormat:fmt, ##__VA_ARGS__]; });
#define BBHTTPLogDebug(fmt, ...)  BBHTTPLog(4, @"DEBUG", ^{ return [NSString stringWithFormat:fmt, ##__VA_ARGS__]; });
#define BBHTTPLogTrace(fmt, ...)  BBHTTPLog(5, @"TRACE", ^{ return [NSString stringWithFormat:fmt, ##__VA_ARGS__]; });
#define BBHTTPCurlDebug(fmt, ...) BBHTTPLog(1, @" CURL", ^{ return [NSString stringWithFormat:fmt, ##__VA_ARGS__]; });



#pragma mark - DRY macros

#define BBHTTPErrorWithFormat(c, fmt, ...) \
    [NSError errorWithDomain:@"com.biasedbit.http" code:c \
                    userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:fmt, ##__VA_ARGS__]}]

// We need this variant because passing a non-statically initialized NSString* instance as fmt raises a warning
#define BBHTTPError(c, description) \
    [NSError errorWithDomain:@"com.biasedbit.http" code:c \
                    userInfo:@{NSLocalizedDescriptionKey: description}]

#define BBHTTPErrorWithReason(c, description, reason) \
    [NSError errorWithDomain:@"com.biasedbit.http" code:c \
                    userInfo:@{NSLocalizedDescriptionKey: description, NSLocalizedFailureReasonErrorKey: reason}]

#define BBHTTPEnsureNotNil(value) NSAssert((value) != nil, @"%s cannot be nil", #value)

#define BBHTTPEnsureSuccessOrReturn0(condition) do { if (!(condition)) return 0; } while(0)

#define BBHTTPSingleton(class, name, value) \
    static class* name = nil; \
    if (name == nil) { \
        static dispatch_once_t name ## _token; \
        dispatch_once(&name##_token, ^{ name = value; }); \
    }

#define BBHTTPSingletonString(name, fmt, ...) \
    static NSString* name = nil; \
    if (name == nil) { \
        static dispatch_once_t name ## _token; \
        dispatch_once(&name##_token, ^{ name = [NSString stringWithFormat:fmt, ##__VA_ARGS__]; }); \
    }

#define BBHTTPSingletonBlock(class, name, block) \
    static class* name = nil; \
    if (name == nil) { \
        static dispatch_once_t name ## _token; \
        dispatch_once(&name##_token, block); \
    }

#define BBHTTPDefineHeaderName(name, override) static NSString* const BBHTTPHeaderName_##name = (override);
#define BBHTTPDefineHeaderValue(value, override) static NSString* const BBHTTPHeaderValue_##value = (override);
#define H(name) BBHTTPHeaderName_##name
#define HV(value) BBHTTPHeaderValue_##value



#pragma mark - Headers names

BBHTTPDefineHeaderName(Host,              @"Host") // Will create BBHTTPHeaderName_Host
BBHTTPDefineHeaderName(UserAgent,         @"User-Agent")
BBHTTPDefineHeaderName(ContentType,       @"Content-Type")
BBHTTPDefineHeaderName(ContentLength,     @"Content-Length")
BBHTTPDefineHeaderName(Accept,            @"Accept")
BBHTTPDefineHeaderName(AcceptLanguage,    @"Accept-Language")
BBHTTPDefineHeaderName(Expect,            @"Expect")
BBHTTPDefineHeaderName(TransferEncoding,  @"Transfer-Encoding")
BBHTTPDefineHeaderName(Date,              @"Date")
BBHTTPDefineHeaderName(Authorization,     @"Authorization")



#pragma mark - Header values

BBHTTPDefineHeaderValue(100Continue,   @"100-Continue") // Will create BBHTTPHeaderValue_100Continue
BBHTTPDefineHeaderValue(Chunked,       @"chunked")



#pragma mark - Utility functions

extern NSString* BBHTTPMimeType(NSString* file);
extern long long BBHTTPCurrentTimeMillis(void);
extern NSString* BBHTTPURLEncode(NSString* string, NSStringEncoding encoding);
