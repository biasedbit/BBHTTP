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

#pragma mark - Enums

typedef NS_ENUM(NSUInteger, BBHTTPProtocolVersion) {
    BBHTTPProtocolVersion_1_0 = 0,
    BBHTTPProtocolVersion_1_1,
};



#pragma mark - Utility functions

NSString* NSStringFromBBHTTPProtocolVersion(BBHTTPProtocolVersion version);
BBHTTPProtocolVersion BBHTTPProtocolVersionFromNSString(NSString* string);



#pragma mark -

@interface BBHTTPResponse : NSObject


#pragma mark Properties

@property(assign, nonatomic, readonly) BBHTTPProtocolVersion version;
@property(assign, nonatomic, readonly) NSUInteger code;
@property(strong, nonatomic, readonly) NSString* message;
@property(strong, nonatomic, readonly) NSDictionary* headers;
@property(assign, nonatomic, readonly, getter = isSuccessful) BOOL successful;
@property(assign, nonatomic, readonly) NSUInteger contentSize;
@property(strong, nonatomic, readonly) id content;


#pragma mark Creation

- (instancetype)initWithVersion:(BBHTTPProtocolVersion)version
                           code:(NSUInteger)code
                     andMessage:(NSString*)message;


#pragma mark Public static methods

+ (BBHTTPResponse*)responseWithStatusLine:(NSString*)statusLine;


#pragma mark Interface

- (void)finishWithContent:(id)content size:(NSUInteger)size successful:(BOOL)successful;
- (NSString*)headerWithName:(NSString*)header;
- (void)setValue:(NSString*)value forHeader:(NSString*)header;
- (NSString*)objectForKeyedSubscript:(NSString*)header;
- (void)setObject:(NSString*)value forKeyedSubscript:(NSString*)header;

@end
