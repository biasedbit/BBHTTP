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

#import "BBHTTPFileWriter.h"

#import "BBHTTPUtils.h"



#pragma mark -

@implementation BBHTTPFileWriter
{
    NSString* _pathToFile;
    NSOutputStream* _stream;
    BOOL _needsCleanup;
}


#pragma mark Creating a new file writer

- (instancetype)initWithTargetFile:(NSString*)pathToFile
{
    self = [super init];
    if (self != nil) {
        _pathToFile = pathToFile;
        _needsCleanup = NO;
    }

    return self;
}


#pragma mark BBHTTPContentHandler

- (BOOL)prepareForResponse:(NSUInteger)statusCode message:(NSString*)message headers:(NSDictionary*)headers
                      error:(NSError**)error
{
    if (![super prepareForResponse:statusCode message:message headers:headers error:error]) return NO;

    _stream = [NSOutputStream outputStreamToFileAtPath:_pathToFile append:NO];
    [_stream open];
    _needsCleanup = YES;

    return YES;
}

- (NSInteger)appendResponseBytes:(uint8_t*)bytes withLength:(NSUInteger)length error:(NSError**)error
{
    NSInteger written = [_stream write:bytes maxLength:length];
    if (written <= 0) [self cleanup];
    if ((written < 0) && (error != NULL)) *error = [_stream streamError];

    return written;
}

- (id)parseContent:(NSError**)error
{
    _needsCleanup = NO;
    if (([_stream streamError] != nil) && (error != NULL)) *error = [_stream streamError];
    if ([_stream streamStatus] != NSStreamStatusClosed) [_stream close];

    // There's never anything to return here, this parser merely pumps data to the output stream.
    return nil;
}

- (void)cleanup
{
    if (!_needsCleanup) return;

    _needsCleanup = NO;
    [_stream close];
    [self deleteFileInBackground];
}


#pragma mark Private helpers

- (void)deleteFileInBackground
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        NSError* error = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:_pathToFile error:&error]) {
            NSError* cause = [[error userInfo] objectForKey:NSUnderlyingErrorKey];
            NSString* description = cause == nil ? [error localizedDescription] : [cause localizedDescription];
            BBHTTPLogWarn(@"[%@] Deletion of partially downloaded file '%@' failed: %@",
                          self, _pathToFile, description);
        } else {
            BBHTTPLogTrace(@"[%@] Deleted partially downloaded file '%@'.", self, _pathToFile);
        }
    });
}

@end
