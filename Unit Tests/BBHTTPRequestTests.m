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

#import <SenTestingKit/SenTestingKit.h>

#import "BBHTTPRequest.h"



#pragma mark -

@interface BBHTTPRequestTests : SenTestCase
@end

@implementation BBHTTPRequestTests

- (void)testFormData
{
    BBHTTPRequest* post = [[BBHTTPRequest alloc] initWithTarget:@"http://biasedbit.com" andVerb:@"POST"];

    NSDictionary* uploadFormData = @{@"foo": @"bar", @"baz": @"2"};
    STAssertTrue([post setUploadFormData:uploadFormData],
                 @"setUploadFormData: returned NO");

    NSString* expectedFormDataString = @"foo=bar&baz=2";
    NSData* expectedFormData = [expectedFormDataString dataUsingEncoding:NSASCIIStringEncoding];

    STAssertNotNil(post[@"Content-Type"],
                   @"Content-Type header is nil");
    STAssertNotNil(post[@"Content-Length"],
                   @"Content-Length header is nil");
    STAssertTrue([post[@"Content-Type"] isEqualToString:@"application/x-www-form-urlencoded"],
                 @"Content-Type header doesn't match expected value");
    STAssertEquals(post.uploadSize, [expectedFormDataString length],
                   @"upload size doesn't match expected value");
    STAssertTrue([expectedFormData isEqualToData:post.uploadData],
                 @"request upload data doesn't match expected value");
}

@end
