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

#import "BBHTTPRequest+PrivateInterface.h"

#import "BBHTTPUtils.h"



#pragma mark -

@implementation BBHTTPRequest (PrivateInterface)

// These are already defined on the main class
@dynamic startTimestamp;
@dynamic endTimestamp;
@dynamic sentBytes;
@dynamic receivedBytes;
@dynamic error;
@dynamic response;


#pragma mark Property access redefinition

- (void)setStartTimestamp:(long long)startTimestamp
{
    _startTimestamp = startTimestamp;
}

- (void)setEndTimestamp:(long long)endTimestamp
{
    _endTimestamp = endTimestamp;
}

- (void)setSentBytes:(NSUInteger)sentBytes
{
    _sentBytes = sentBytes;
}

- (void)setReceivedBytes:(NSUInteger)receivedBytes
{
    _receivedBytes = receivedBytes;
}

- (void)setError:(NSError*)error
{
    _error = error;
}

- (void)setResponse:(BBHTTPResponse*)response
{
    _response = response;
}


#pragma mark Events

- (BOOL)executionStarted
{
    if ([self hasFinished]) return NO;

    self.startTimestamp = BBHTTPCurrentTimeMillis();
    if (self.startBlock != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.startBlock();
            self.startBlock = nil;
        });
    }

    return YES;
}

- (BOOL)executionFailedWithError:(NSError*)error
{
    if ([self hasFinished]) return NO;

    self.endTimestamp = BBHTTPCurrentTimeMillis();
    self.error = error;

    if (self.finishBlock != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.finishBlock(self);
            self.finishBlock = nil;
        });
    }

    return YES;
}

- (BOOL)executionFinishedWithFinalResponse:(BBHTTPResponse*)response
{
    if ([self hasFinished]) return NO;

    self.endTimestamp = BBHTTPCurrentTimeMillis();
    self.response = response;

    if (self.finishBlock != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.finishBlock(self);
            self.finishBlock = nil;
        });
    }

    return YES;
}

- (BOOL)uploadProgressedToCurrent:(NSUInteger)current ofTotal:(NSUInteger)total
{
    if ([self hasFinished]) return NO;

    self.sentBytes = current;

    if (self.uploadProgressBlock != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.uploadProgressBlock(current, total);
        });
    }

    return YES;
}

- (BOOL)downloadProgressedToCurrent:(NSUInteger)current ofTotal:(NSUInteger)total
{
    if ([self hasFinished]) return NO;

    self.receivedBytes = current;

    if (self.downloadProgressBlock != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.downloadProgressBlock(current, total);
        });
    }

    return YES;
}

@end
