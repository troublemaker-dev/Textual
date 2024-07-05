/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2018 Codeux Software, LLC & respective contributors.
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

#import "TPCResourceManager.h"
#import "TPCPreferencesUserDefaultsLocal.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark -
#pragma mark Reading & Writing

typedef NS_ENUM(NSUInteger, TPCPreferencesComparator) {
	TPCPreferencesComparatorEqual 			= 0,
	TPCPreferencesComparatorAnchorFront		= 1,
	TPCPreferencesComparatorAnchorBack		= 2
};

@interface TPCPreferencesUserDefaults ()
- (void)_setObject:(nullable id)value forKey:(NSString *)defaultName;
@end

@implementation TPCPreferencesUserDefaults (TPCPreferencesUserDefaultsLocal)

+ (BOOL)key:(NSString *)defaultName1 matchesKey:(NSString *)defaultName2 usingComparator:(TPCPreferencesComparator)comparator
{
	NSParameterAssert(defaultName1 != nil);
	NSParameterAssert(defaultName2 != nil);

	if (comparator == TPCPreferencesComparatorEqual) {
		if ([defaultName1 isEqualToString:defaultName2]) {
			return YES;
		}
	} else if (comparator == TPCPreferencesComparatorAnchorFront) {
		if ([defaultName1 hasPrefix:defaultName2]) {
			return YES;
		}
	} else if (comparator == TPCPreferencesComparatorAnchorBack) {
		if ([defaultName1 hasSuffix:defaultName2]) {
			return YES;
		}
	}

	return NO;
}

+ (BOOL)keyIsExcludedFromExportImport:(NSString *)defaultName
{
	NSParameterAssert(defaultName != nil);

	NSDictionary<NSString *, NSNumber *> *cachedValues =
	[TPCResourceManager dictionaryFromResources:@"KeysExcludedFromExport" inDirectory:@"Preferences"];

	__block BOOL returnValue = NO;

	[cachedValues enumerateKeysAndObjectsUsingBlock:^(NSString *cachedKey, NSNumber *cachedObject, BOOL *stop) {
		if ([self key:defaultName matchesKey:cachedKey usingComparator:cachedObject.unsignedIntegerValue]) {
			*stop = YES;

			returnValue = YES;
		}
	}];

	if (returnValue) {
		return YES;
	}

	return ([self keyAppearsInMasterList:defaultName] == NO);
}

+ (BOOL)keyIsExcludedFromMigration:(NSString *)defaultName
{
	NSParameterAssert(defaultName != nil);

	NSDictionary<NSString *, NSNumber *> *cachedValues =
	[TPCResourceManager dictionaryFromResources:@"KeysExcludedFromMigrate" inDirectory:@"Preferences"];

	__block BOOL returnValue = NO;

	[cachedValues enumerateKeysAndObjectsUsingBlock:^(NSString *cachedKey, NSNumber *cachedObject, BOOL *stop) {
		if ([self key:defaultName matchesKey:cachedKey usingComparator:cachedObject.unsignedIntegerValue]) {
			*stop = YES;

			returnValue = YES;
		}
	}];

	if (returnValue) {
		return YES;
	}

	return ([self keyAppearsInMasterList:defaultName] == NO);
}

+ (BOOL)keyAppearsInMasterList:(NSString *)defaultName
{
	NSDictionary<NSString *, NSNumber *> *cachedValues =
	[TPCResourceManager dictionaryFromResources:@"PreferenceKeyMasterList" inDirectory:@"Preferences"];

	__block BOOL returnValue = NO;

	[cachedValues enumerateKeysAndObjectsUsingBlock:^(NSString *cachedKey, NSNumber *cachedObject, BOOL *stop) {
		if ([self key:defaultName matchesKey:cachedKey usingComparator:cachedObject.unsignedIntegerValue]) {
			*stop = YES;

			returnValue = YES;
		}
	}];

	return returnValue;
}

+ (BOOL)keyIsExcludedFromContainer:(NSString *)defaultName
{
	NSParameterAssert(defaultName != nil);

	NSDictionary<NSString *, NSNumber *> *cachedValues =
	[TPCResourceManager dictionaryFromResources:@"KeysExcludedFromContainer" inDirectory:@"Preferences"];

	__block BOOL returnValue = NO;

	[cachedValues enumerateKeysAndObjectsUsingBlock:^(NSString *cachedKey, NSNumber *cachedObject, BOOL *stop) {
		if ([self key:defaultName matchesKey:cachedKey usingComparator:cachedObject.unsignedIntegerValue]) {
			*stop = YES;

			returnValue = YES;
		}
	}];

	return returnValue;
}

- (void)_migrateObject:(nullable id)value forKey:(NSString *)defaultName
{
	if ([TPCPreferencesUserDefaults keyIsExcludedFromContainer:defaultName]) {
		[[NSUserDefaults standardUserDefaults] setObject:value forKey:defaultName];

		return;
	}

	[self _setObject:value forKey:defaultName];
}

@end

#pragma mark -
#pragma mark Object KVO Proxying

@implementation TPCPreferencesUserDefaultsController

+ (TPCPreferencesUserDefaultsController *)sharedUserDefaultsController
{
	static id sharedSelf = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		TPCPreferencesUserDefaults *defaults = [TPCPreferencesUserDefaults sharedUserDefaults];

		 sharedSelf = [[super allocWithZone:NULL] _initWithDefaults:defaults initialValues:nil];

		[sharedSelf setAppliesImmediately:YES];
	});

	return sharedSelf;
}

- (instancetype)_initWithDefaults:(nullable NSUserDefaults *)defaults initialValues:(nullable NSDictionary<NSString *, id> *)initialValues
{
	return [super initWithDefaults:defaults initialValues:initialValues];
}

+ (instancetype)alloc
{
	return [self sharedUserDefaultsController];
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone
{
	return [self sharedUserDefaultsController];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)init
{
	return [self.class sharedUserDefaultsController];
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
	return [self.class sharedUserDefaultsController];
}

- (instancetype)initWithDefaults:(nullable NSUserDefaults *)defaults initialValues:(nullable NSDictionary<NSString *, id> *)initialValues
{
	return [self.class sharedUserDefaultsController];
}
#pragma clang diagnostic pop

- (id)defaults
{
	return [TPCPreferencesUserDefaults sharedUserDefaults];
}

@end

NS_ASSUME_NONNULL_END
