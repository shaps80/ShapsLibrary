/*
   Copyright (c) 2013 Snippex. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY Snippex `AS IS' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL Snippex OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SPXRestURLOperation.h"
#import "SPXRestResponse.h"
#import "SPXRestPayload.h"

@interface SPXRestRequest : SPXRestURLOperation

@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, readonly) NSDictionary *allHTTPHeaders;

/**
 @abstract
 */
- (id)initWithURL:(NSURL *)url method:(NSString *)method;

/**
 */
- (void)setTimeoutInterval:(NSTimeInterval)timeout;

/**
 */
- (void)setResponseHandler:(id <SPXResponseHandler>)handler;

/**
 @abstract
 */
- (void)setPayload:(id <SPXRestPayloadProtocol>)payload;

/**
 @abstract
 */
- (void)setHeaders:(NSDictionary *)headers;

/**
 @abstract
 */
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;

/**
 @abstract
 */
- (void)setParameters:(NSDictionary *)parameters;

/**
 @abstract
 */
- (void)setValue:(NSString *)value forParameter:(NSString *)parameter;

/**
 @abstract
 */
- (void)setHandlesCookiesAutomatically:(BOOL)shouldHandleCookies;

@end
