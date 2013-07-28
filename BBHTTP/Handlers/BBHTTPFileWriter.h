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

#import "BBHTTPSelectiveDiscarder.h"


#pragma mark -

/**
 Response parser that inherits selective behavior from `<BBHTTPSelectiveResponseParser>` and dumps all the data it
 receives through `<appendResponseBytes:withLength:>` to a the file it was initialized with.
 
 If the file cannot be written to or there's not enough space left on device, the request will fail.

 If an error occurs while transferring data to the the file, the partial file will automatically be deleted.
 */
@interface BBHTTPFileWriter : BBHTTPSelectiveDiscarder


#pragma mark Creating a new file writer

- (instancetype)initWithTargetFile:(NSString*)pathToFile;

@end
