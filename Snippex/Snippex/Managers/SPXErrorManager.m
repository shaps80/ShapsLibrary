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

#import "SPXErrorManager.h"
#import "SPXDefines.h"

const NSString *kCLErrorUserTitle					= @"UserTitle";
const NSString *kCLErrorUserDescription				= @"UserDescription";
const NSString *kCLErrorCancelButton				= @"CancelButtonTitle";
const NSString *kCLErrorOtherButtons				= @"OtherButtonTitles";

static NSDictionary *errorsDictionary;

@interface SPXErrorManager ()
@property (nonatomic, strong) NSDictionary *errorsDictionary;
@property (nonatomic) Class alert;
@end

@implementation SPXErrorManager

#pragma mark - Lifecycle

+(SPXErrorManager *)sharedInstance
{
    if (!errorsDictionary)
    {
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"Errors" withExtension:@"plist"];
        NSAssert(url, @"Unable to load default errors.plist, have you mispelled the filename or forgotten to initialize with +initializeWithPlist: or +initializeWithDictionary:");
        [SPXErrorManager initializeWithPlist:url];
    }

	static SPXErrorManager *_sharedInstance = nil;
	static dispatch_once_t oncePredicate;
	dispatch_once(&oncePredicate, ^{
		_sharedInstance = [[self alloc] initWithDictionary:errorsDictionary];
	});

	return _sharedInstance;
}

+(NSDictionary *)dictionaryFromURL:(NSURL *)urlToPlist
{
	if (![[NSFileManager defaultManager] fileExistsAtPath:urlToPlist.path])
	{
		NSException *exception = [NSException exceptionWithName:NSInvalidArgumentException
														 reason:[NSString stringWithFormat:@"No errors plist found at %@", urlToPlist]
													   userInfo:nil];
		[exception raise];
	}

	NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfURL:urlToPlist];

	if (![dictionary isKindOfClass:[NSDictionary class]])
	{
		NSException *exception = [NSException exceptionWithName:NSInvalidArgumentException reason:@"The errors plist could not be loaded." userInfo:nil];
		[exception raise];
	}

	return dictionary;
}

+(void)initializeWithPlist:(NSURL *)urlToPlist
{
    DLog(@"Initialized");
	errorsDictionary = [SPXErrorManager dictionaryFromURL:urlToPlist];
}

+(void)initializeWithDictionary:(NSDictionary *)dictionary
{
	errorsDictionary = [dictionary copy];
}

-(id)initWithDictionary:(NSDictionary *)dictionary
{
	self = [super init];

	if (self)
	{
		_errorsDictionary = [dictionary copy];
	}

	return self;
}

-(id)initWithPlist:(NSURL *)urlToPlist
{
	return [self initWithDictionary:[SPXErrorManager dictionaryFromURL:urlToPlist]];
}

-(void)registerAlertViewClass:(Class)alertViewClass
{
	if (!([alertViewClass conformsToProtocol:@protocol(SPXAlertProtocol)]))
	{
		NSException *exception = [NSException exceptionWithName:NSInvalidArgumentException reason:@"The specified class does not conform to SPXAlertProtocol" userInfo:nil];
		[exception raise];
	}
	else
		_alert = alertViewClass;
}

#pragma mark - Helper methods

-(NSDictionary *)paramsForCode:(NSInteger)errorCode
						 class:(Class)class
{
	if (!class)
		class = [NSObject class];

	NSDictionary *classParams = nil;

	while (!(classParams = [_errorsDictionary objectForKey:NSStringFromClass(class)]))
	{
		if (![class superclass])
			break;

		class = [class superclass];
	}

	if (!classParams)
	{
		NSString *message = [NSString stringWithFormat:@"-presentErrorForCode:className:completion: No error dictionary found for %@",
							 NSStringFromClass(class)];
		NSAssert(classParams, message);
	}

	NSDictionary *params = [classParams objectForKey:[NSString stringWithFormat:@"%li", (long)errorCode]];

	if (!params)
	{
		// fall back to generic error in release build
		params =
		@{
		kCLErrorUserTitle : @"Failed",
		kCLErrorUserDescription : @"An unknown error occurred.",
		kCLErrorCancelButton : @"OK"
		};
	}
	
	return params;
}

#pragma mark - Returning error details

-(NSString *)messageForCode:(NSInteger)code class:(Class)class
{
	NSDictionary *params = [self paramsForCode:code class:class];
	NSString *message = [params objectForKey:kCLErrorUserDescription];

	return message;
}

-(NSString *)messageForError:(NSError *)error class:(Class)class
{
	return [self messageForCode:error.code class:class];
}

-(void)errorForCode:(NSInteger)code
			  class:(Class)class
			  title:(NSString *__autoreleasing *)title
			message:(NSString *__autoreleasing *)message
{
	[self setTitle:title message:message cancel:nil other:nil code:code class:class];
}

-(void)errorForCode:(NSInteger)code
			  class:(Class)class
			  title:(NSString *__autoreleasing *)title
			message:(NSString *__autoreleasing *)message
  cancelButtonTitle:(NSString *__autoreleasing *)cancelTitle
  otherButtonTitles:(NSArray *__autoreleasing *)otherTitles
{
	[self setTitle:title message:message cancel:cancelTitle other:otherTitles code:code class:class];
}

-(void)errorForError:(NSError *)error
  		       class:(Class)class
			   title:(NSString **)title
			 message:(NSString **)message
   cancelButtonTitle:(NSString **)cancelTitle
   otherButtonTitles:(NSArray **)otherTitles
{
	[self setTitle:title message:message cancel:cancelTitle other:otherTitles code:error.code class:class];
}

-(void)setTitle:(NSString **)title
		message:(NSString **)message
		 cancel:(NSString **)cancel
		  other:(NSArray **)other
		   code:(NSInteger)code
		  class:(Class)class
{
	NSDictionary *params = [self paramsForCode:code class:class];

	NSAssert(([params objectForKey:kCLErrorUserTitle] && title), @"title variable is not initialized");
	NSAssert(([params objectForKey:kCLErrorUserDescription] && message), @"message variable is not initialized");

	if (title)
		*title = [params objectForKey:kCLErrorUserTitle];
	if (message)
		*message = [params objectForKey:kCLErrorUserDescription];
	if (cancel)
		*cancel = [params objectForKey:kCLErrorCancelButton];
	if (other)
		*other = [params objectForKey:kCLErrorOtherButtons];
}

#pragma mark - Presenting error details

-(void)presentErrorForError:(NSError *)error class:(Class)class
				 completion:(SPXAlertCompletionBlock)completion
{
	[self presentErrorForCode:error.code class:class completion:completion]; 
}

-(void)presentErrorForCode:(NSInteger)errorCode
					 class:(Class)class
				completion:(SPXAlertCompletionBlock)completion
{
	NSDictionary *params = [self paramsForCode:errorCode class:class];

	id <SPXAlertProtocol> alert = [[_alert alloc] initWithTitle:[params objectForKey:kCLErrorUserTitle]
													   message:[params objectForKey:kCLErrorUserDescription]
												   cancelTitle:[params objectForKey:kCLErrorCancelButton]
												   otherTitles:[params objectForKey:kCLErrorOtherButtons]];
	
	[alert showWithCompletion:completion];

	// if we don't have a title or cancel button, auto dismiss after 1 second.
	if (![params objectForKey:kCLErrorCancelButton] && ![params objectForKey:kCLErrorOtherButtons])
		if ([alert respondsToSelector:@selector(dismissWithDelay:)])
			[alert dismissWithDelay:1];
}

@end