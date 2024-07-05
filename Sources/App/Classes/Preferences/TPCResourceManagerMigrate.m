/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 *   Copyright (c) 2024 Codeux Software, LLC & respective contributors.
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

#import "TDCAlert.h"
#import "TLOLocalization.h"
#import "TLOpenLink.h"
#import "TPCApplicationInfo.h"
#import "TPCPathInfo.h"
#import "TPCPreferencesUserDefaults.h"
#import "TPCPreferencesUserDefaultsLocal.h"
#import "TPCResourceManagerMigratePrivate.h"

NS_ASSUME_NONNULL_BEGIN

/*
 Standalone Classic - This refers to an installation of Textual 7
 downloaded from codeux.com before the transition to sandbox.

 Mac App Store - This refers to an installation of Textual 7
 downloaded from the Mac App Store.

 Migration steps:
	1. 	Check the age of the current group container.
		If it wasn't recently created. Like within the
		span of a few seconds ago, then stop.
	2. 	Locate Standalone Classic preferences
	3. 	If located, is the value of TXRunCount >= 1
		If yes, perform migration on that installation.
	4. 	If migration is not performed, then locate
		Mac App Store preferences if this is the first
		time this installation of Textual has launched.
	5. 	If located, is the value of TXRunCount >= 1
		If yes, have the preferences been modified with
		the last 30 days (see MaximumAgeOfStalePreferences)
		If yes, perform migration on that installation.

 Data and files are migrated by creating copies.
 After migration is completed, the user will be asked if
 they want to remove (delete / erase) the old contents.
*/
@interface TPCPathInfo (TPCResourceManagerMigrate)
@property (class, readonly, copy, nullable) NSURL *gcStandaloneClassicURL;
@property (class, readonly, copy, nullable) NSURL *gcMacAppStoreURL;
@property (class, readonly, copy, nullable) NSURL *extensionsStandaloneClassicURL;
@property (class, readonly, copy, nullable) NSURL *extensionsMacAppStoreURL;
@property (class, readonly, copy, nullable) NSURL *preferencesMacAppStoreURL;
@end

@interface TPCPreferencesUserDefaults ()
- (void)_migrateObject:(nullable id)value forKey:(NSString *)defaultName;
@end

/* Textual will import preferences from a Mac App Store purchase
 if this is the first launch. This macro defines the maximum amount
 of time that was allowed to elapse since the preferences for that
 installation was last modified. We don't want to import an installation
 that the user setup a year ago on a whim and only used it a day. */
#define MaximumAgeOfStalePreferences 		(60 * 60 * 24 * 30)  // 30 days

/* Defaults key set after migration is performed. */
/* YES if migration was completed */
#define MigrationCompleteDefaultsKey					@"TPCResourceManagerMigrate -> Migrated Resources"

/* Integer for the installation that was migrated */
/* nil value or zero result is possible even after migration
 is complete because nothing might have been migrated. */
/* Migration is designed to be one shot. */
#define MigrationInstallationMigratedDefaultsKey		@"TPCResourceManagerMigrate -> Installation Migrated"

/* Whether the user has dismissed the notification alert */
#define MigrationUserAcknowledgedDefaultsKey			@"TPCResourceManagerMigrate -> User Acknowledged"

/* Whether the user wants to delete old files */
#define MigrationUserPrefersPruningDefaultsKey			@"TPCResourceManagerMigrate -> User Prefers Pruning Files"

/* YES if there are no more extensions to prune
 which means we can bypass all the directory scans. */
#define MigrationAllExtensionsPrunedDefaultsKey			@"TPCResourceManagerMigrate -> All Extensions Pruned"

/* An array of preference keys migrated */
#define MigrationKeysImportedDefaultsKey				@"TPCResourceManagerMigrate -> Imported Keys"

/* Result returned when performing migration of a specific installation. */
typedef NS_ENUM(NSUInteger, TPCResourceManagerMigrationResult)
{
	/* Migration was performed successfully */
	TPCResourceManagerMigrationResultSuccess,

	/* Candidate for migration is not suitable.
	 For example, a Mac App Store installation was located
	 but the age of its preference file is out of range. */
	TPCResourceManagerMigrationResultNotSuitable,

	/* An error occurred during migration. */
	/* Errors are logged to console. */
	TPCResourceManagerMigrationResultError
};

/* The installation attempting migration / migrated */
typedef NS_ENUM(NSUInteger, TPCResourceManagerMigrationInstallation)
{
	/* Standalone Classic */
	TPCResourceManagerMigrationInstallationStandaloneClassic 	= 100,

	/* Mac App Store */
	TPCResourceManagerMigrationInstallationMacAppStore			= 200
};

@implementation TPCResourceManager (TPCResourceManagerMigrate)

+ (void)migrateResources
{
	LogToConsoleInfo("Preparing to migrate group containers");

	/* Do not migrate if we have done so in the past. */
	if ([RZUserDefaults() boolForKey:MigrationCompleteDefaultsKey]) {
		[self _notifyGroupContainerMigratedFromDefaults];
		[self _pruneExtensionSymbolicLinksFromDefaults];

		LogToConsoleInfo("Group containers have already been migrated");

		return;
	}

	/* Do not migrate if the age of the current group container is not recent.
	 The age is only going to be recent the launch it was created. */
	if ([self _ageOfCurrentContainerIsRecent] == NO) {
		[self _setMigrationCompleteAndAcknowledged];

		LogToConsoleInfo("Current group container was not created recently");

		return;
	}

	/* This code can probably be condensed. Not important enough. */
	/* Migrate Standalone Classic? */
	LogToConsoleInfo("Start: Migrating Standalone Classic installation");

	TPCResourceManagerMigrationResult tryMigrateStandaloneClass = [self _migrateStandaloneClassic];

	switch (tryMigrateStandaloneClass) {
		case TPCResourceManagerMigrationResultSuccess:
			[self _setMigrationCompleteForStandaloneClassic];

			LogToConsoleInfo("End: Migrating Standalone Classic successful");

			return;
		case TPCResourceManagerMigrationResultError:
			LogToConsoleInfo("End: Migrating Standalone Classic failed. Stopping all migration");

			return;
		case TPCResourceManagerMigrationResultNotSuitable:
			LogToConsoleInfo("End: Migrating Standalone Classic failed. Installation is not suitable");

			break; // Try Mac App Store next
	}

	/* Migrate Standalone Classic? */
	LogToConsoleInfo("Start: Migrating Mac App Store installation");

	TPCResourceManagerMigrationResult tryMigrateMacAppStore = [self _migrateMacAppStore];

	switch (tryMigrateMacAppStore) {
		case TPCResourceManagerMigrationResultSuccess:
			[self _setMigrationCompleteForMacAppStore];

			LogToConsoleInfo("End: Migrating Mac App Store successful");

			return;
		case TPCResourceManagerMigrationResultError:
			LogToConsoleInfo("End: Migrating Mac App Store failed. Stopping all migration");

			return;
		case TPCResourceManagerMigrationResultNotSuitable:
			LogToConsoleInfo("End: Migrating Mac App Store failed. Installation is not suitable");

			break;
	}

	/* No other migration path */
	[self _setMigrationCompleteAndAcknowledged];
}

#pragma mark -
#pragma mark Standalone Classic Migration

+ (TPCResourceManagerMigrationResult)_migrateStandaloneClassic /* YES on success */
{
	/* Bundle identifier did not change during non-sandbox -> sandbox transition
	 which means we create a new blank defaults object because sending the bundle
	 identifier for the current app to -initWithSuiteName: is not allowed. */
	NSUserDefaults *standaloneDefaults =
	[[NSUserDefaults alloc] initWithSuiteName:[self _defaultsSuiteNameForStandaloneClassic]];

	if (standaloneDefaults == nil) {
		LogToConsoleFault("NSUserDefaults object could not be created for standalone domain. "
						  "This should be impossible as the bundle identifier has not changed.");

		return TPCResourceManagerMigrationResultError;
	}

	/* Import preference keys */
	NSDictionary *preferences = standaloneDefaults.dictionaryRepresentation;

	NSUInteger runCount = [preferences unsignedIntegerForKey:@"TXRunCount"];

	if (runCount == 0) {
		LogToConsoleError("Migration of Standalone Classic has zero run count");

		return TPCResourceManagerMigrationResultNotSuitable;
	}

	/* Import preferences */
	/* Import preferences before migrating group container that way if a
	 hard failure is encountered there, it wont undo the progress we made.
	 The user will want something rather than nothing. Especially when it
	 comes to their configuration. Custom content can be copied manually. */
	NSArray *importedKeys = [self _importPreferences:preferences];

	/* Migrate group container */
	BOOL migrateContainer = [self _migrateGroupContainerContentsForStandaloneClassic];

	if (migrateContainer == NO) {
		return TPCResourceManagerMigrationResultError;
	}

	/* Finish */
	[self _setListOfImportedKeys:importedKeys];

	[self _notifyGroupContainerMigratedForStandaloneClassic];

	return TPCResourceManagerMigrationResultSuccess;
}

+ (TPCResourceManagerMigrationResult)_migrateMacAppStore /* YES on success */
{
	/* Preflight checks */
	if ([self _modificationDateForMacAppStorePreferencesIsRecent] == NO) {
		LogToConsoleDebug("Migration of Mac App Store has stale preferences file");

		return TPCResourceManagerMigrationResultNotSuitable;
	}

	NSUserDefaults *appStoreDefaults = 
	[[NSUserDefaults alloc] initWithSuiteName:[self _defaultsSuiteNameForMacAppStore]];

	if (appStoreDefaults == nil) {
		LogToConsoleInfo("NSUserDefaults object could not be created for Mac App Store domain");

		return TPCResourceManagerMigrationResultNotSuitable;
	}

	/* Import preference keys */
	NSDictionary *preferences = appStoreDefaults.dictionaryRepresentation;

	NSUInteger runCount = [preferences unsignedIntegerForKey:@"TXRunCount"];

	if (runCount == 0) {
		LogToConsoleError("Migration of Mac App Store has zero run count");

		return TPCResourceManagerMigrationResultNotSuitable;
	}

	/* Import preferences */
	NSArray *importedKeys = [self _importPreferences:preferences];

	/* Migrate group container */
	BOOL migrateContainer = [self _migrateGroupContainerContentsForMacAppStore];

	if (migrateContainer == NO) {
		return TPCResourceManagerMigrationResultError;
	}

	/* Finish */
	[self _setListOfImportedKeys:importedKeys];

	[self _notifyGroupContainerMigratedForMacAppStore];

	return TPCResourceManagerMigrationResultSuccess;
}

+ (NSArray<NSString *> *)_importPreferences:(NSDictionary<NSString *, id> *)dict
{
	NSParameterAssert(dict != nil);

	LogToConsoleInfo("Start: Migrating preferences");

	NSMutableArray *importedKeys = [NSMutableArray arrayWithCapacity:dict.count];

	[dict enumerateKeysAndObjectsUsingBlock:^(NSString *key, id object, BOOL *stop) {
		if ([TPCPreferencesUserDefaults keyIsExcludedFromMigration:key]) {
#ifdef DEBUG
			LogToConsoleDebug("Key is excluded from migration: '%@'", key);
#endif

			return;
		}

		[importedKeys addObject:key];

		[RZUserDefaults() _migrateObject:object forKey:key];
	}];

	LogToConsoleInfo("End: Migrating preferences");

	return [importedKeys copy];
}

+ (void)_removeImportedKeysForInstallation:(TPCResourceManagerMigrationInstallation)installation
{
	LogToConsoleInfo("Start: Remove old preferences");

	NSArray *listOfKeys = [RZUserDefaults() arrayForKey:MigrationKeysImportedDefaultsKey];

	if (listOfKeys == nil) {
		LogToConsoleInfo("No preferences to remove");

		return;
	}

	NSUserDefaults *defaults = 
	[[NSUserDefaults alloc] initWithSuiteName:[self _defaultsSuiteNameForInstallation:installation]];

	if (defaults == nil) {
		LogToConsoleInfo("NSUserDefaults object could not be created for [%@] installation",
			[self _descriptionOfInstallation:installation]);

		return;
	}

	for (id key in listOfKeys) {
		/* This data could have been manipulated from the outside. */
		if ([key isKindOfClass:[NSString class]] == NO) {
			LogToConsoleFault("Corrupted data found inside list of keys");

			continue;
		}

#ifdef DEBUG
		LogToConsoleDebug("Removing key: '%@'", key);
#endif

		[defaults removeObjectForKey:key];
	}

	[self _unsetListOfImportedKeys];

	LogToConsoleInfo("End: Remove old preferences - Removed: %lu", listOfKeys.count);
}

+ (void)_removeImportedKeysForStandaloneClassic
{
	[self _removeImportedKeysForInstallation:TPCResourceManagerMigrationInstallationStandaloneClassic];
}

+ (void)_removeImportedKeysForMacAppStore
{
	[self _removeImportedKeysForInstallation:TPCResourceManagerMigrationInstallationMacAppStore];
}

+ (void)_setListOfImportedKeys:(nullable NSArray<NSString *> *)list
{
	[RZUserDefaults() _migrateObject:list forKey:MigrationKeysImportedDefaultsKey];
}

+ (void)_unsetListOfImportedKeys
{
	[self _setListOfImportedKeys:nil];
}

+ (void)_setMigrationComplete
{
	[RZUserDefaults() _migrateObject:@(YES) forKey:MigrationCompleteDefaultsKey];
}

+ (void)_setMigrationCompleteForStandaloneClassic
{
	[RZUserDefaults() _migrateObject:@(TPCResourceManagerMigrationInstallationStandaloneClassic) forKey:MigrationInstallationMigratedDefaultsKey];

	[self _setMigrationComplete];
}

+ (void)_setMigrationCompleteForMacAppStore
{
	[RZUserDefaults() _migrateObject:@(TPCResourceManagerMigrationInstallationMacAppStore) forKey:MigrationInstallationMigratedDefaultsKey];

	[self _setMigrationComplete];
}

+ (void)_setMigrationCompleteAndAcknowledged
{
	[self _setMigrationComplete];

	[self _setUserAcknowledgedMigration];
}

#pragma mark -
#pragma mark Group Container Migration

+ (BOOL)_migrateGroupContainerContentsForInstallation:(TPCResourceManagerMigrationInstallation)installation
{
	LogToConsoleInfo("Start: Migrate group container for '%@'",
		[self _descriptionOfInstallation:installation]);

	NSURL *oldLocation = [self _groupContainerURLForInstallation:installation];

	if (oldLocation == nil) {
		LogToConsoleError("Cannot migrate group container contents because of nil source location");

		return NO;
	}

	NSURL *newLocation = [TPCPathInfo groupContainerURL];

	if (newLocation == nil) {
		LogToConsoleError("Cannot migrate group container contents because of nil destination location");

		return NO;
	}

	/* Migration is performed by recursively copying contents effectively merging the contents. */
	/* If a file already exists, it will not be overwrote under any condition. */
	/* This should only be performed with no real resources in the group container
	 destination group container anyways so this wont matter much. */
	BOOL result =
	[RZFileManager() mergeDirectoryAtURL:oldLocation
					  withDirectoryAtURL:newLocation
								 options:(CSFileManagerOptionsEnumerateDirectories |
										  CSFileManagerOptionContinueOnError |
										  CSFileManagerOptionsCreateDirectory |
										  CSFileManagerCreateSymbolicLinkForPackages)];

	LogToConsoleInfo("End: Migrate group container - Result: %@",
		StringFromBOOL(result));

	return result;
}

+ (BOOL)_migrateGroupContainerContentsForStandaloneClassic
{
	return [self _migrateGroupContainerContentsForInstallation:TPCResourceManagerMigrationInstallationStandaloneClassic];
}

+ (BOOL)_migrateGroupContainerContentsForMacAppStore
{
	return [self _migrateGroupContainerContentsForInstallation:TPCResourceManagerMigrationInstallationMacAppStore];
}

+ (void)_notifyGroupContainerMigratedForInstallation:(TPCResourceManagerMigrationInstallation)installation
{
	LogToConsoleInfo("Notifying user that installation of type [%@] migration performed",
		[self _descriptionOfInstallation:installation]);

	TVCAlert *alert =
	[TDCAlert alertWithMessage:TXTLS(@"Prompts[qy4-5o]")
						 title:TXTLS(@"Prompts[ios-na]")
				 defaultButton:TXTLS(@"Prompts[zjw-bd]")
			   alternateButton:nil
				   otherButton:TXTLS(@"Prompts[d90-au]")
				suppressionKey:nil
			   suppressionText:TXTLS(@"Prompts[q3t-45]")
			   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id  _Nullable underlyingAlert) 
	 {
		[self _setUserAcknowledgedMigration];

		if (suppressed) {
			[self _setUserPrefersPruningFiles];

			[self _removeImportedKeysForInstallation:installation];
			[self _removeGroupContainerContentsForInstallation:installation];
		} else {
			[self _unsetListOfImportedKeys];
		}
	}];

	[alert setButtonClickedBlock:^BOOL(TVCAlert *sender, TVCAlertResponseButton buttonClicked) {
		[TLOpenLink openWithString:@"https://help.codeux.com/textual/miscellaneous/Why-Did-Textual-Copy-Files-to-a-New-Location.kb" inBackground:NO];

		return NO;
	} forButton:TVCAlertResponseButtonThird];
}

+ (void)_notifyGroupContainerMigratedFromDefaults
{
	/* This method is only invoked internally if the defaults key
	 MigrationCompleteDefaultsKey is set which means we are just
	 asking the user what they want to do with their files until
	 they acknowledge the alert. */
	BOOL userAcknowledged = [RZUserDefaults() boolForKey:MigrationUserAcknowledgedDefaultsKey];

	if (userAcknowledged) {
		return; // Stop migration
	}

	TPCResourceManagerMigrationInstallation installation = [RZUserDefaults() unsignedIntegerForKey:MigrationInstallationMigratedDefaultsKey];

	/* Seeing as this value comes from outside and is manipulatable,
	 we use a switch statement to validate value instead of calling
	 directly into -_notifyGroupContainerMigratedForInstallation:
	 which assumes good faith for its arguments. */
	switch (installation) {
		case TPCResourceManagerMigrationInstallationStandaloneClassic:
			[self _notifyGroupContainerMigratedForStandaloneClassic];

			break;
		case TPCResourceManagerMigrationInstallationMacAppStore:
			[self _notifyGroupContainerMigratedForMacAppStore];

			break;
		default:
			break;
	}
}

+ (void)_notifyGroupContainerMigratedForStandaloneClassic
{
	[self _notifyGroupContainerMigratedForInstallation:TPCResourceManagerMigrationInstallationStandaloneClassic];
}

+ (void)_notifyGroupContainerMigratedForMacAppStore
{
	[self _notifyGroupContainerMigratedForInstallation:TPCResourceManagerMigrationInstallationMacAppStore];
}

+ (void)_setUserAcknowledgedMigration
{
	[RZUserDefaults() _migrateObject:@(YES) forKey:MigrationUserAcknowledgedDefaultsKey];
}

+ (void)_setUserPrefersPruningFiles
{
	[RZUserDefaults() _migrateObject:@(YES) forKey:MigrationUserPrefersPruningDefaultsKey];
}

#pragma mark -
#pragma mark Group Container Removal

+ (BOOL)_removeGroupContainerContentsForInstallation:(TPCResourceManagerMigrationInstallation)installation
{
	LogToConsoleInfo("Start: Remove group container for '%@'",
		[self _descriptionOfInstallation:installation]);

	NSURL *gcLocation = [self _groupContainerURLForInstallation:installation];

	if (gcLocation == nil) {
		LogToConsoleError("Cannot remove group container contents because of nil location");

		return NO;
	}

	/* -_listOfExtensionsForInstallation: should only return nil on fatal errors.
	 It will not return nil for an extension folder that does not exist, or is empty. */
	NSArray *oldExtensions = [self _listOfExtensionsForInstallation:installation];

	if (gcLocation == nil) {
		LogToConsoleError("Cannot remove group container contents because of nil extension list");

		return NO;
	}

	LogToConsoleInfo("Removing group container contents at URL: %@", gcLocation);

	BOOL result = [RZFileManager() removeContentsOfDirectoryAtURL:gcLocation
													excludingURLs:oldExtensions
														  options:(CSFileManagerOptionContinueOnError)];

	LogToConsoleInfo("End: Remove group container - Result: %@",
		StringFromBOOL(result));

	return result;
}

+ (BOOL)_removeGroupContainerContentsForStandaloneClassic
{
	return [self _removeGroupContainerContentsForInstallation:TPCResourceManagerMigrationInstallationStandaloneClassic];
}

+ (BOOL)_removeGroupContainerContentsForMacAppStore
{
	return [self _removeGroupContainerContentsForInstallation:TPCResourceManagerMigrationInstallationMacAppStore];
}

#pragma mark -
#pragma mark Extension Pruning

+ (void)_pruneExtensionSymbolicLinksForInstallation:(TPCResourceManagerMigrationInstallation)installation
{
	/* When you create a copy of a bundle programmatically, macOS will move it to
	 quarantine. The user is then notified macOS can't verify that it isn't malware.
	 That is less than ideal when performing migration. */
	/* When migration is performed, we create a symbolic link to the original
	 extension instead of copying it to the new location. If the symbolic link
	 at the new location is replaced, then that extension is now just dangling
	 never to be used again. */
	/* TPCResourceManager will handle garbage collection. It will compare the
	 contents of the old location and new location each launch. If a symbolic
	 link is not present for an extension in the old location, that extension
	 is deleted. Once all extensions are deleted, a flag is set to stop pruning
	 so we don't keep scanning the old location forever. */
	LogToConsoleInfo("Start: Pruning extensions for '%@'",
		[self _descriptionOfInstallation:installation]);

	NSArray *oldExtensions = [self _listOfExtensionsForInstallation:installation];

	if (oldExtensions == nil) {
		/* Helper method will describe error. */

		return;
	}

	if (oldExtensions.count == 0) {
		LogToConsoleInfo("Source location for extensions to prune is empty");

		[self _setAllExtensionSymbolicLinksPruned];

		return;
	}

	NSURL *newLocation = [TPCPathInfo customExtensionsURL];

	if (newLocation == nil) {
		LogToConsoleError("Cannot prune extensions because of nil destination location");

		return;
	}

	NSUInteger numberPruned = 0;
	NSUInteger numberRemaining = 0;

	for (NSURL *oldExtension in oldExtensions) {
		NSString *name = [oldExtension resourceValueForKey:NSURLNameKey];
		
		NSNumber *isPackage = [oldExtension resourceValueForKey:NSURLIsPackageKey];

		if ([name hasSuffix:@".bundle"] == NO ||
			(isPackage == nil || isPackage.boolValue == NO))
		{
#ifdef DEBUG
			LogToConsoleDebug("Ignoring non-bundle: '%@' - isPackage: %@", name,
				StringFromBOOL(isPackage.boolValue));
#endif

			continue;
		}

		NSURL *newExtension = [newLocation URLByAppendingPathComponent:name];

		/* Should we check if the symbolic link points to this extension
		 and not some other random file on the operating system?
		 The likelihood of the user having a symbolic link they
		 created is near zero if not zero. This is already over engineered. */
		BOOL pruned = NO;

		if ([self _fileAtURLIsSymbolicLink:newExtension] == NO) {
#ifdef DEBUG
			LogToConsoleDebug("Pruning URL: '%@'", oldExtension);
#endif

			NSError *deleteError = nil;

			pruned = [RZFileManager() removeItemAtURL:oldExtension error:&deleteError];

			if (deleteError) {
				LogToConsoleError("Failed to prune extension at URL ['%@']: %@",
					oldExtension, deleteError.localizedDescription);
			}
		}

		if (pruned) {
			numberPruned += 1;
		} else {
			numberRemaining += 1;
		}
	} // Directory list for loop

	if (numberRemaining == 0) {
		[self _setAllExtensionSymbolicLinksPruned];
	}

	LogToConsoleInfo("End: Pruning extensions completed. "
					 "Number remaining: %lu, Number pruned: %lu",
		numberRemaining, numberPruned);
}

+ (void)_pruneExtensionSymbolicLinksForStandaloneClassic
{
	[self _pruneExtensionSymbolicLinksForInstallation:TPCResourceManagerMigrationInstallationStandaloneClassic];
}

+ (void)_pruneExtensionSymbolicLinksForMacAppStore
{
	[self _pruneExtensionSymbolicLinksForInstallation:TPCResourceManagerMigrationInstallationMacAppStore];
}

+ (void)_pruneExtensionSymbolicLinksFromDefaults
{
	BOOL doPrune = [RZUserDefaults() boolForKey:MigrationUserPrefersPruningDefaultsKey];

	if (doPrune == NO) {
		return; // Stop pruning
	}

	BOOL pruningExhausted = [RZUserDefaults() boolForKey:MigrationAllExtensionsPrunedDefaultsKey];

	if (pruningExhausted) {
		return; // Stop pruning
	}

	TPCResourceManagerMigrationInstallation installation = [RZUserDefaults() unsignedIntegerForKey:MigrationInstallationMigratedDefaultsKey];

	switch (installation) {
		case TPCResourceManagerMigrationInstallationStandaloneClassic:
			[self _pruneExtensionSymbolicLinksForStandaloneClassic];

			break;
		case TPCResourceManagerMigrationInstallationMacAppStore:
			[self _pruneExtensionSymbolicLinksForMacAppStore];

			break;
		default:
			break;
	}
}

+ (void)_setAllExtensionSymbolicLinksPruned
{
	[RZUserDefaults() _migrateObject:@(YES) forKey:MigrationAllExtensionsPrunedDefaultsKey];
}

#pragma mark -
#pragma mark Utilities

+ (NSString *)_descriptionOfInstallation:(TPCResourceManagerMigrationInstallation)installation
{
	/* This is used for logging so is not localized.
	 Localize is use changes. */
	switch (installation) {
		case TPCResourceManagerMigrationInstallationStandaloneClassic:
			return @"Standalone Classic";
		case TPCResourceManagerMigrationInstallationMacAppStore:
			return @"Mac App Store";
		default:
			return @"<Unknown Installation>";
	}
}

+ (nullable NSURL *)_groupContainerURLForInstallation:(TPCResourceManagerMigrationInstallation)installation
{
	NSURL *gcLocation = nil;

	switch (installation) {
		case TPCResourceManagerMigrationInstallationStandaloneClassic:
			gcLocation = [TPCPathInfo gcStandaloneClassicURL];

			break;
		case TPCResourceManagerMigrationInstallationMacAppStore:
			gcLocation = [TPCPathInfo gcMacAppStoreURL];

			break;
		default:
			return nil;
	}

	if (gcLocation == nil) {
		LogToConsoleFault("Group container URL for installation [%@] is nil",
			[self _descriptionOfInstallation:installation]);
	}

	return gcLocation;
}

+ (nullable NSURL *)_extensionsURLForInstallation:(TPCResourceManagerMigrationInstallation)installation
{
	NSURL *gcLocation = nil;

	switch (installation) {
		case TPCResourceManagerMigrationInstallationStandaloneClassic:
			gcLocation = [TPCPathInfo extensionsStandaloneClassicURL];

			break;
		case TPCResourceManagerMigrationInstallationMacAppStore:
			gcLocation = [TPCPathInfo extensionsMacAppStoreURL];

			break;
		default:
			return nil;
	}

	if (gcLocation == nil) {
		LogToConsoleFault("Extensions URL for installation [%@] is nil",
			[self _descriptionOfInstallation:installation]);
	}

	return gcLocation;
}

+ (nullable NSString *)_defaultsSuiteNameForInstallation:(TPCResourceManagerMigrationInstallation)installation
{
	if (installation == TPCResourceManagerMigrationInstallationMacAppStore) {
		return @"8482Q6EPL6.com.codeux.irc.textual";
	}

	return nil;
}

+ (nullable NSString *)_defaultsSuiteNameForStandaloneClassic
{
	return [self _defaultsSuiteNameForInstallation:TPCResourceManagerMigrationInstallationStandaloneClassic];
}

+ (nullable NSString *)_defaultsSuiteNameForMacAppStore
{
	return [self _defaultsSuiteNameForInstallation:TPCResourceManagerMigrationInstallationMacAppStore];
}

+ (nullable NSArray<NSURL *> *)_listOfExtensionsForInstallation:(TPCResourceManagerMigrationInstallation)installation
{
	NSURL *oldLocation = [self _extensionsURLForInstallation:installation];

	if (oldLocation == nil) {
		LogToConsoleError("Cannot list extensions because of nil source location");

		return nil;
	}

	if ([RZFileManager() fileExistsAtURL:oldLocation] == NO) {
		return @[];
	}

	NSError *listExtensionsError = nil;

	NSArray *oldExtensions = [RZFileManager() contentsOfDirectoryAtURL:oldLocation
											includingPropertiesForKeys:@[NSURLNameKey, NSURLIsPackageKey]
															   options:0
																 error:&listExtensionsError];

	if (listExtensionsError) {
		LogToConsoleError("Unable to list contents of extensions at URL ['%@']: %@",
			oldLocation, listExtensionsError.localizedDescription);

		return nil;
	}

	return oldExtensions;
}

+ (BOOL)_ageOfCurrentContainerIsRecent
{
	NSURL *newLocation = [TPCPathInfo groupContainerURL];

	if (newLocation == NO) {
		return NO;
	}

	NSTimeInterval age = [self _ageOfFileAtURL:newLocation];

	/* macOS will create the group container the first time
	 we ask for its path. If the group container wasn't created
	 recently, then we have no reason to perform migration to it.
	 In theory, this could probably be narrowed down further as
	 the interval should be sub-second. */
	return (age < 2.0);
}

+ (NSTimeInterval)_modificationDateForMacAppStorePreferencesIsRecent
{
	NSURL *location = [TPCPathInfo preferencesMacAppStoreURL];

	if (location == nil) {
		return NO;
	}

	NSTimeInterval age = [self _intervalSinceFileAtURLLastModified:location];

	return (age >= 0 && age <= MaximumAgeOfStalePreferences);
}

+ (NSTimeInterval)_ageOfFileAtURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSError *error = nil;

	NSTimeInterval age = [url intervalSinceCreatedWithError:&error];

	if (error) {
		/* This is purposely considered debug information as the user knowing
		 a file not existing is not an error when that is probable outcome. */
		LogToConsoleDebug("Error caught when calculating age of file: %@",
			error.localizedDescription);
	}

	return age;
}

+ (NSTimeInterval)_intervalSinceFileAtURLLastModified:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSError *error = nil;

	NSTimeInterval age = [url intervalSinceLastModificationWithError:&error];

	if (error) {
		/* This is purposely considered debug information as the user knowing
		 a file not existing is not an error when that is probable outcome. */
		LogToConsoleDebug("Error caught when calculating age of file: %@",
			error.localizedDescription);
	}

	return age;
}

+ (BOOL)_fileAtURLIsSymbolicLink:(NSURL *)url
{
	NSParameterAssert(url != nil);

	/* Skip check if file exists because no resource value
	 will be returned if that is the case. */
	NSNumber *isSymblink = [url resourceValueForKey:NSURLIsSymbolicLinkKey];

	return (isSymblink != nil && isSymblink.boolValue);
}

@end

#pragma mark -
#pragma mark Path Information

@implementation TPCPathInfo (TPCResourceManagerMigrate)

+ (nullable NSURL *)gcStandaloneClassicURL
{
	/* The reason we are not using -containerURLForSecurityApplicationGroupIdentifier: in this context is because
	 during testing, that method was returning ~/Library/Containers/com.codeux.apps.textual instead of the group
	 container location. I assume it's related to the fact the group identifier is same as the app's identifier.
	 This is not a make-or-break location in which hard coding will hurt it. */
//	NSURL *baseURL = [RZFileManager() containerURLForSecurityApplicationGroupIdentifier:@"com.codeux.apps.textual"];
	NSURL *baseURL = [[TPCPathInfo userHomeURL] URLByAppendingPathComponent:@"/Library/Group Containers/com.codeux.apps.textual/"];

	return baseURL;
}

+ (nullable NSURL *)gcMacAppStoreURL
{
//	NSURL *baseURL = [RZFileManager() containerURLForSecurityApplicationGroupIdentifier:@"8482Q6EPL6.com.codeux.irc.textual"];
	NSURL *baseURL = [[TPCPathInfo userHomeURL] URLByAppendingPathComponent:@"/Library/Group Containers/8482Q6EPL6.com.codeux.irc.textual"];

	return baseURL;
}

+ (nullable NSURL *)extensionsStandaloneClassicURL
{
	NSURL *sourceURL = self.gcStandaloneClassicURL;

	if (sourceURL == nil) {
		return nil;
	}

	return [sourceURL URLByAppendingPathComponent:@"/Library/Application Support/Textual/Extensions/"];
}

+ (nullable NSURL *)extensionsMacAppStoreURL
{
	NSURL *sourceURL = self.gcMacAppStoreURL;

	if (sourceURL == nil) {
		return nil;
	}

	return [sourceURL URLByAppendingPathComponent:@"/Library/Application Support/Textual/Extensions/"];
}

+ (nullable NSURL *)preferencesMacAppStoreURL
{
	NSURL *sourceURL = self.gcMacAppStoreURL;

	if (sourceURL == nil) {
		return nil;
	}

	return [sourceURL URLByAppendingPathComponent:@"/Library/Preferences/8482Q6EPL6.com.codeux.irc.textual.plist"];
}

@end

NS_ASSUME_NONNULL_END
