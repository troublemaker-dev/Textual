/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2008 - 2010 Satoshi Nakagawa <psychs AT limechat DOT net>
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
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

#import "TPCTheme.h"

NS_ASSUME_NONNULL_BEGIN

TEXTUAL_EXTERN NSString * const TPCThemeControllerCustomThemeNameBasicPrefix;
TEXTUAL_EXTERN NSString * const TPCThemeControllerCustomThemeNameCompletePrefix;

TEXTUAL_EXTERN NSString * const TPCThemeControllerBundledThemeNameBasicPrefix;
TEXTUAL_EXTERN NSString * const TPCThemeControllerBundledThemeNameCompletePrefix;

TEXTUAL_EXTERN NSNotificationName const TPCThemeControllerThemeListDidChangeNotification;

/* Theme is not loaded until main window is woken which means
 while you could in theory access this object before then,
 objects below that are marked non-nil will actually be nil. */
@interface TPCThemeController : NSObject
@property (readonly, strong) TPCTheme *theme;

@property (readonly, strong) TPCThemeSettings *settings;

@property (readonly) TPCThemeStorageLocation storageLocation;

@property (readonly, copy) NSString *name;

@property (readonly, copy) NSURL *originalURL; // Where original copy of theme is.
@property (readonly, copy) NSURL *temporaryURL; // Where cached copy of theme is.

@property (readonly, copy) NSString *originalPath;
@property (readonly, copy) NSString *temporaryPath;

@property (readonly, copy) NSString *cacheToken;

@property (getter=isBundledTheme, readonly) BOOL bundledTheme;

/* Calls for all themes */
- (void)enumerateAvailableThemesWithBlock:(void(NS_NOESCAPE ^)(NSString *fileName, TPCThemeStorageLocation storageLocation, BOOL multipleVariants, BOOL *stop))enumerationBlock;

- (BOOL)themeExists:(NSString *)themeName;

+ (nullable NSString *)pathOfThemeWithName:(NSString *)themeName;
+ (nullable NSString *)pathOfThemeWithName:(NSString *)themeName storageLocation:(nullable TPCThemeStorageLocation *)storageLocation;

+ (nullable NSString *)buildFilename:(NSString *)name forStorageLocation:(TPCThemeStorageLocation)storageLocation;

+ (nullable NSString *)extractThemeSource:(NSString *)source;
+ (nullable NSString *)extractThemeName:(NSString *)source;

+ (TPCThemeStorageLocation)storageLocationOfThemeWithName:(NSString *)themeName;

+ (nullable NSString *)descriptionForStorageLocation:(TPCThemeStorageLocation)storageLocation;
@end

NS_ASSUME_NONNULL_END
