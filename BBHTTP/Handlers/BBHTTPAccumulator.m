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

#import "BBHTTPAccumulator.h"



#pragma mark -

@implementation BBHTTPAccumulator
{
    NSOutputStream* _stream;
}


#pragma mark BBHTTPSelectiveDiscarder behavior overrides

- (NSInteger)appendResponseBytes:(uint8_t*)bytes withLength:(NSUInteger)length error:(NSError**)error
{
    if (_stream == nil) {
        _stream = [NSOutputStream outputStreamToMemory];
        [_stream open];
    }

    NSInteger written = [_stream write:bytes maxLength:length];
    if (written <= 0) [_stream close];
    if ((written < 0) && (error != NULL)) *error = [_stream streamError];

    return written;
}

- (id)parseContent:(NSError**)error
{
    if (_stream == nil) return nil; // No data received

    if ([_stream streamError] != nil) {
        if (error != NULL) *error = [_stream streamError];
        return nil;
    }

    if ([_stream streamStatus] != NSStreamStatusClosed) [_stream close];
    NSData* data = [_stream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];

    _stream = nil;

    return data;
}

@end
