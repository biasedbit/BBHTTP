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

#include "BBHTTPUtils.h"

#import <sys/time.h>

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    #import <MobileCoreServices/MobileCoreServices.h>
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
    #import <CoreServices/CoreServices.h>
#endif



#pragma mark - Logging

NSUInteger BBHTTPLogLevel = BBHTTPLogLevelWarn;

void BBHTTPLog(NSUInteger level, NSString* prefix, NSString* (^statement)())
{
    // The block logging approach does incur some overhead but since default log level is WARN, the number of
    // statements supressed (trace, debug & info) is so high that it compensates to not evaluate the formatted
    // expression for these cases.
    if (level <= BBHTTPLogLevel) NSLog(@"BBHTTP | %@ | %@", prefix, statement());
}



#pragma mark - Utility functions

NSString* BBHTTPMimeType(NSString* file)
{
#ifndef __UTTYPE__
    return @"application/octet-stream";
#else
    NSString* ext = [file pathExtension];
    if (ext == nil) return @"application/octet-stream";

    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                            (__bridge CFStringRef)ext, NULL);
    if (!UTI) return nil;

    CFStringRef registeredType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
    CFRelease(UTI);

    if (!registeredType) return @"application/octet-stream";
    else return CFBridgingRelease(registeredType);
#endif
}

long long BBHTTPCurrentTimeMillis()
{
    struct timeval t;
    gettimeofday(&t, NULL);

    return (((int64_t) t.tv_sec) * 1000) + (((int64_t) t.tv_usec) / 1000);
}

NSString* BBHTTPURLEncode(NSString* string, NSStringEncoding encoding)
{
    return (__bridge_transfer NSString*)
            CFURLCreateStringByAddingPercentEscapes(NULL,
                                                    (__bridge CFStringRef)string,
                                                    NULL,
                                                    (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                    CFStringConvertNSStringEncodingToEncoding(encoding));
}
