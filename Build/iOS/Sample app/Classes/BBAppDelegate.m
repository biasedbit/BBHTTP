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

#import "BBAppDelegate.h"

#import "BBHotpotato.h"



#pragma mark -

@implementation BBAppDelegate


#pragma mark UIApplicationDelegate

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions
{
    [self getExample];
//    [self postExample];

    return YES;
}

- (void)getExample
{
    [[BBHTTPRequest getFrom:@"http://biasedbit.com"] execute:^(BBHTTPResponse* response) {
         NSLog(@"Finished: %u %@ -- received %u bytes of '%@' %@",
               response.code, response.message, [response.data length], response[@"Content-Type"], response.headers);
     } error:^(NSError* error) {
         NSLog(@"Error: %@", [error localizedDescription]);
     }];
}

- (void)postExample
{
    BBHTTPRequest* upload = [BBHTTPRequest postFile:@"/path/to/file" to:@"http://api.target.url/"];
    upload.uploadProgressBlock = ^(NSUInteger current, NSUInteger total) {
        NSLog(@"--> %u/%u", current, total);
    };
    upload.downloadProgressBlock = ^(NSUInteger current, NSUInteger total) {
        NSLog(@"<== %u/%u%@", current, total, total == 0 ? @" (chunked download, total size unknown)" : @"");
    };

    [upload setup:^(BBHTTPRequest* request) {
        request[@"User-Agent"] = @"<- super cool, eh?";
    } andExecute:^(BBHTTPResponse* response) {
        NSLog(@"%@ %u %@ %@", NSStringFromBBHTTPProtocolVersion(response.version),
              response.code, response.message, response.headers);
    } error:^(NSError* error) {
        NSLog(@"Error: %@", [error localizedDescription]);
    }];
}

@end
