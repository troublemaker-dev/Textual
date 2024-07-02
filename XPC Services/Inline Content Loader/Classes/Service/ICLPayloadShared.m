/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2017, 2020 Codeux Software, LLC & respective contributors.
 *       Please see Acknowledgements.pdf for additional information.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *  * Neither the name of Textual, "Codeux Software, LLC", nor the
 *    names of its contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *********************************************************************** */

#import "NSObjectHelperPrivate.h"
#import "ICLPayload.h"
#import "ICLPayloadInternal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation ICLPayload

- (instancetype)init
{
	[self doesNotRecognizeSelector:_cmd];

	return nil;
}

- (instancetype)initOnMutate
{
	if ((self = [super initOnMutate])) {
		[self populateDefaultsPostflight];

		return self;
	}

	return nil;
}

- (BOOL)populateWithDecoder:(NSCoder *)aDecoder
{
	self->_contentLength = [aDecoder decodeUnsignedIntegerForKey:@"contentLength"];
	self->_contentSize = [aDecoder decodeSizeForKey:@"contentSize"];

	self->_styleResources = [aDecoder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSURL class], nil]
													 forKey:@"styleResources"];

	self->_scriptResources = [aDecoder decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], [NSURL class], nil]
													  forKey:@"scriptResources"];

	self->_html = [aDecoder decodeStringForKey:@"html"];

	self->_entrypoint = [aDecoder decodeStringForKey:@"entrypoint"];
	self->_entrypointPayload = [aDecoder decodeDictionaryForKey:@"entrypointPayload"];

	self->_url = [aDecoder decodeObjectOfClass:[NSURL class] forKey:@"url"];
	self->_urlToInline = [aDecoder decodeObjectOfClass:[NSURL class] forKey:@"urlToInline"];

	self->_lineNumber = [aDecoder decodeStringForKey:@"lineNumber"];

	self->_uniqueIdentifier = [aDecoder decodeStringForKey:@"uniqueIdentifier"];
	self->_viewIdentifier = [aDecoder decodeStringForKey:@"viewIdentifier"];

	self->_index = [aDecoder decodeUnsignedIntegerForKey:@"index"];

	self->_classAttribute = [aDecoder decodeStringForKey:@"classAttribute"];

	return YES;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeUnsignedInteger:self->_contentLength forKey:@"contentLength"];
	[aCoder encodeSize:self->_contentSize forKey:@"contentSize"];

	[aCoder maybeEncodeObject:self->_styleResources forKey:@"styleResources"];
	[aCoder maybeEncodeObject:self->_scriptResources forKey:@"scriptResources"];

	[aCoder encodeString:self->_html forKey:@"html"];

	[aCoder maybeEncodeObject:self->_entrypoint forKey:@"entrypoint"];
	[aCoder maybeEncodeObject:self->_entrypointPayload forKey:@"entrypointPayload"];

	[aCoder encodeObject:self->_url forKey:@"url"];
	[aCoder encodeObject:self->_urlToInline forKey:@"urlToInline"];

	[aCoder encodeString:self->_lineNumber forKey:@"lineNumber"];

	[aCoder encodeString:self->_uniqueIdentifier forKey:@"uniqueIdentifier"];
	[aCoder encodeString:self->_viewIdentifier forKey:@"viewIdentifier"];

	[aCoder encodeUnsignedInteger:self->_index forKey:@"index"];

	[aCoder encodeString:self->_classAttribute forKey:@"classAttribute"];
}

+ (BOOL)supportsSecureCoding
{
	return YES;
}

- (void)populateDefaultsPostflight
{
	if (self.initializedAsCopy == NO) {
		self->_contentSize = NSZeroSize;
	}

	SetVariableIfNil(self->_urlToInline, self->_url);
	SetVariableIfNil(self->_styleResources, @[]);
	SetVariableIfNil(self->_scriptResources, @[]);
	SetVariableIfNil(self->_html, @"");
	SetVariableIfNil(self->_classAttribute, @"");
}

- (void)initializedClassHealthCheck
{
	NSParameterAssert(self->_html != nil);
	NSParameterAssert(self->_url != nil);
	NSParameterAssert(self->_urlToInline != nil);
	NSParameterAssert(self->_lineNumber != nil);
	NSParameterAssert(self->_uniqueIdentifier != nil);
	NSParameterAssert(self->_viewIdentifier != nil);
	NSParameterAssert(self->_classAttribute != nil);
}

- (id)copyAsMutable:(BOOL)mutableCopy uniquing:(BOOL)uniquing
{
	ICLPayload *object = [self allocForCopyAsMutable:mutableCopy];

	object->_contentLength = self->_contentLength;
	object->_contentSize = self->_contentSize;

	object->_styleResources = self->_styleResources;
	object->_scriptResources = self->_scriptResources;

	object->_html = self->_html;

	object->_entrypoint = self->_entrypoint;
	object->_entrypointPayload = self->_entrypointPayload;

	object->_url = self->_url;
	object->_urlToInline = self->_urlToInline;

	object->_lineNumber = self->_lineNumber;

	object->_uniqueIdentifier = self->_uniqueIdentifier;
	object->_viewIdentifier = self->_viewIdentifier;

	object->_index = self->_index;

	object->_classAttribute = self->_classAttribute;

	return [object initOnCopy];
}

- (__kindof XRPortablePropertyObject *)mutableClass
{
	return [ICLPayloadMutable self];
}

- (NSDictionary<NSString *, id<NSCopying>> *)entrypointPayload
{
	NSDictionary *payload = self->_entrypointPayload;

	if (payload == nil) {
		return [self entrypointPayloadDefaultContext];
	}

	return payload;
}

- (NSDictionary<NSString *, id<NSCopying>> *)entrypointPayloadDefaultContext
{
	return @{
		@"class" : self->_classAttribute,
		@"html" : self->_html,
		@"url" : self->_url,
		@"urlToInline" : self->_urlToInline,
		@"lineNumber" : self->_lineNumber,
		@"uniqueIdentifier" : self->_uniqueIdentifier
	};
}

- (void)entrypointPayloadSetContext
{
	/* Set context to payload that module sets. */
	/* The values set in the context don't change so we
	 are safe setting and forgetting. */
	NSDictionary *payload = self->_entrypointPayload;

	if (payload == nil) {
		return;
	}

	NSDictionary *payloadToSet = [self entrypointPayloadDefaultContext];

	self->_entrypointPayload = [payload dictionaryByAddingEntries:payloadToSet];
}

- (NSString *)address
{
	return self->_url.absoluteString;
}

- (NSString *)addressToInline
{
	return self->_urlToInline.absoluteString;
}

@end

#pragma mark -

@implementation ICLPayloadMutable

@dynamic urlToInline;
@dynamic contentLength;
@dynamic contentSize;
@dynamic styleResources;
@dynamic scriptResources;
@dynamic html;
@dynamic entrypoint;
@dynamic entrypointPayload;
@dynamic classAttribute;

- (BOOL)isMutable
{
	return YES;
}

- (__kindof XRPortablePropertyDict *)immutableClass
{
	return [ICLPayload self];
}

DESIGNATED_INITIALIZER_EXCEPTION_BODY_BEGIN
- (instancetype)init
{
	return [self initOnMutate];
}
DESIGNATED_INITIALIZER_EXCEPTION_BODY_END

- (void)setUrlToInline:(NSURL *)urlToInline
{
	NSParameterAssert(urlToInline != nil);
	NSParameterAssert(urlToInline.isFileURL == NO);

	if (self->_urlToInline != urlToInline) {
		self->_urlToInline = [urlToInline copy];
	}
}

- (void)setContentLength:(unsigned long long)contentLength
{
	if (self->_contentLength != contentLength) {
		self->_contentLength = contentLength;
	}
}

- (void)setContentSize:(NSSize)contentSize
{
	self->_contentSize = contentSize;
}

- (void)setStyleResources:(NSArray<NSURL *> *)styleResources
{
	NSParameterAssert(styleResources != nil);

	if (self->_styleResources != styleResources) {
		self->_styleResources = [styleResources copy];
	}
}

- (void)setScriptResources:(NSArray<NSURL *> *)scriptResources
{
	NSParameterAssert(scriptResources != nil);

	if (self->_scriptResources != scriptResources) {
		self->_scriptResources = [scriptResources copy];
	}
}

- (void)setHtml:(NSString *)html
{
	NSParameterAssert(html != nil);

	if (self->_html != html) {
		self->_html = [html copy];
	}
}

- (void)setEntrypoint:(nullable NSString *)entrypoint
{
	if (self->_entrypoint != entrypoint) {
		self->_entrypoint = [entrypoint copy];
	}
}

- (void)setEntrypointPayload:(nullable NSDictionary<NSString *, id<NSCopying>> *)entrypointPayload
{
	if (self->_entrypointPayload != entrypointPayload) {
		self->_entrypointPayload = [entrypointPayload copy];

		[self entrypointPayloadSetContext];
	}
}

- (void)setClassAttribute:(NSString *)classAttribute
{
	NSParameterAssert(classAttribute != nil);

	if (self->_classAttribute != classAttribute) {
		self->_classAttribute = [classAttribute copy];
	}
}

@end

NS_ASSUME_NONNULL_END
