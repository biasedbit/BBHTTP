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


#pragma mark Property access redefinition

- (long long)startTimestamp
{
    return _startTimestamp;
}

- (void)setStartTimestamp:(long long)startTimestamp
{
    _startTimestamp = startTimestamp;
}

- (long long)endTimestamp
{
    return _endTimestamp;
}

- (void)setEndTimestamp:(long long)endTimestamp
{
    _endTimestamp = endTimestamp;
}

- (NSUInteger)sentBytes
{
    return _sentBytes;
}

- (void)setSentBytes:(NSUInteger)sentBytes
{
    _sentBytes = sentBytes;
}

- (NSUInteger)receivedBytes
{
    return _receivedBytes;
}

- (void)setReceivedBytes:(NSUInteger)receivedBytes
{
    _receivedBytes = receivedBytes;
}

- (NSError*)error
{
    return _error;
}

- (void)setError:(NSError*)error
{
    _error = error;
}

- (BBHTTPResponse*)response
{
    return _response;
}

- (void)setResponse:(BBHTTPResponse*)response
{
    _response = response;
}


#pragma mark Events

- (void)executionStarted
{
    self.startTimestamp = BBHTTPCurrentTimeMillis();
    if (self.startBlock != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.startBlock();
        });
    }
}

- (void)executionFailedWithError:(NSError*)error
{
    self.endTimestamp = BBHTTPCurrentTimeMillis();
    self.error = error;

    if (self.finishBlock != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.finishBlock(self);
        });
    }
}

- (void)executionFinishedWithFinalResponse:(BBHTTPResponse*)response
{
    self.endTimestamp = BBHTTPCurrentTimeMillis();
    self.response = response;

    if (self.finishBlock != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.finishBlock(self);
        });
    }
}

- (void)uploadProgressedToCurrent:(NSUInteger)current ofTotal:(NSUInteger)total
{
    self.sentBytes = current;

    if (self.uploadProgressBlock != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.uploadProgressBlock(current, total);
        });
    }
}

- (void)downloadProgressedToCurrent:(NSUInteger)current ofTotal:(NSUInteger)total
{
    self.receivedBytes = current;

    if (self.downloadProgressBlock != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.downloadProgressBlock(current, total);
        });
    }
}

@end
