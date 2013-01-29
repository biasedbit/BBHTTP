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

#pragma mark -

/**
 Defines the interface for a response content handler.
 
 When a request is performed, its response content may be handled differently according to the implementation of the
 content handler it is configured to use.
 
 For instance, to handle JSON, the response content bytes would be read to a buffer and, when complete, that buffer
 would be converted to a JSON object.
 
 For examples of implementations of this protocol, take a look at `<BBHTTPAccumulator>` or `<BBHTTPFileWriter>`.
 */
@protocol BBHTTPContentHandler <NSObject>


@required

/**
 @return `YES` if this content handler accepts the response, `NO` otherwise.
 */
- (BOOL)prepareForResponse:(NSUInteger)statusCode message:(NSString*)message headers:(NSDictionary*)headers
                      error:(NSError**)error;
- (NSInteger)appendResponseBytes:(uint8_t*)bytes withLength:(NSUInteger)length error:(NSError**)error;
- (id)parseContent:(NSError**)error;


@optional

/**
 Perform additional cleanup, if needed.
 */
- (void)cleanup;

@end
