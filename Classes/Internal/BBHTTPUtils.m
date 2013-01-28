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

#include "BBHTTPUtils.h"

#import <sys/time.h>

#if TARGET_OS_IPHONE
    #import <MobileCoreServices/MobileCoreServices.h>
#else
    #import <CoreServices/CoreServices.h>
#endif



#pragma mark - Logging

NSUInteger BBHTTPLogLevel = BBHTTPLogLevelWarn;

void BBHTTPLog(NSUInteger level, NSString* prefix, NSString* format, ...)
{
    if (level <= BBHTTPLogLevel) {
        va_list list;
        va_start(list, format);
        NSString* fmt = [NSString stringWithFormat:@"BBHTTP | %@ | %@", prefix, format];
        NSLogv(fmt, list);
        va_end(list);
    }
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
