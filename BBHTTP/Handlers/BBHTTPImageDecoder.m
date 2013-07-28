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

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
   #import <UIKit/UIKit.h>
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
   #import <Cocoa/Cocoa.h>
#endif

#import "BBHTTPImageDecoder.h"

#import "BBHTTPUtils.h"



#pragma mark -

@implementation BBHTTPImageDecoder


#pragma mark Creation

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        self.acceptableContentTypes = @[@"image/"]; // accept anything that begins with image/
    }

    return self;
}


#pragma mark BBHTTPAccumulator behavior override

- (id)parseContent:(NSError**)error
{
    // super ensures we have a valid response code and a valid content type
    NSData* data = [super parseContent:error];
    if (((error != NULL) && (*error != nil)) || (data == nil)) return nil;

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    UIImage* image = [UIImage imageWithData:data];
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
    NSImage* image = [[NSImage alloc] initWithData:data];
#endif
    if (image == nil) {
        if (error != NULL) *error = BBHTTPError(BBHTTPErrorCodeImageDecodingFailed, @"Image decoding failed");
        return data;
    }

    return image;
}

@end
