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
@property (class, readonly, copy, nullable) NSURL *preferencesStandaloneClassicURL;
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
#define MigrationCompleteDefaultsKey		@"TPCResourceManagerMigrate -> Migrated Group Containers"

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
	TPCResourceManagerMigrationInstallationStandaloneClassic,
	
	/* Mac App Store */
	TPCResourceManagerMigrationInstallationMacAppStore
};

@implementation TPCResourceManager (TPCResourceManagerMigrate)

+ (void)migrateResources
{
	LogToConsoleInfo("Preparing to migrate group containers");

	/* Do not migrate if we have done so in the past. */
	if ([RZUserDefaults() boolForKey:MigrationCompleteDefaultsKey]) {
		LogToConsoleInfo("Group containers have already been migrated");

		return;
	}

	/* Do not migrate if the age of the current group container is not recent.
	 The age is only going to be recent the launch it was created. */
	if ([self _ageOfCurrentContainerIsRecent] == NO) {
		[self _setMigrationComplete];

		LogToConsoleInfo("Current group container was not created recently");

		return;
	}

	/* Migrate Standalone Classic? */
	LogToConsoleInfo("Start: Migrating Standalone Classic installation");

	TPCResourceManagerMigrationResult tryMigrateStandaloneClass = [self _migrateStandaloneClassic];

	switch (tryMigrateStandaloneClass) {
		case TPCResourceManagerMigrationResultSuccess:
			[self _setMigrationComplete];

			LogToConsoleInfo("End: Migrating Standalone Classic successful.");

			return;
		case TPCResourceManagerMigrationResultError:
			LogToConsoleInfo("End: Migrating Standalone Classic failed. Stopping all migration.");

			return;
		case TPCResourceManagerMigrationResultNotSuitable:
			LogToConsoleInfo("End: Migrating Standalone Classic failed. Installation is not suitable.");

			break; // Try Mac App Store next
	}




}

#pragma mark -
#pragma mark Standalone Classic Migration

+ (TPCResourceManagerMigrationResult)_migrateStandaloneClassic /* YES on success */
{
	/* Bundle identifier did not change during non-sandbox -> sandbox transition
	 which means we create a new blank defaults object because sending the bundle
	 identifier for the current app to -initWithSuiteName: is not allowed. */
	NSUserDefaults *standaloneDefaults = [[NSUserDefaults alloc] initWithSuiteName:nil];

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

//	[self _importPreferences:preferences];

	/* Migrate group container */
	BOOL migrateContainer = [self _migrateGroupContainerContentsForStandaloneClassic];

	if (migrateContainer == NO) {
		return TPCResourceManagerMigrationResultError;
	}

	[self _notifyGroupContainerMigratedForStandaloneClassic];

	return TPCResourceManagerMigrationResultSuccess;
}

+ (void)_importPreferences:(NSDictionary<NSString *, id> *)dict
{
	NSParameterAssert(dict != nil);

	LogToConsoleInfo("Start: Migrating preferences");

	[dict enumerateKeysAndObjectsUsingBlock:^(NSString * key, id object, BOOL *stop) {
		if ([TPCPreferencesUserDefaults keyIsExcludedFromMigration:key]) {
			/*			LogToConsoleDebug("Key is excluded from migration: '%@'", key); */

			return;
		}

		[RZUserDefaults() _migrateObject:object forKey:key];
	}];

	LogToConsoleInfo("End: Migrating preferences");
}

+ (void)_setMigrationComplete
{
	[RZUserDefaults() setBool:YES forKey:MigrationCompleteDefaultsKey];

	LogToConsoleInfo("Set migration is complete flag");
}

#pragma mark -
#pragma mark Group Container Migration

+ (BOOL)_migrateGroupContainerContentsForInstallation:(TPCResourceManagerMigrationInstallation)installation
{
	LogToConsoleInfo("Start: Migrate group container for '%@'",
		[self _descriptionOfInstallation:installation]);

	NSURL *oldLocation = [self _groupContainerURLForInstallation:installation];

	if (oldLocation == nil) {
		LogToConsoleError("Cannot migrate group container contents because of nil source location.");

		return NO;
	}

	NSURL *newLocation = [TPCPathInfo groupContainerURL];

	if (newLocation == nil) {
		LogToConsoleError("Cannot migrate group container contents because of nil destination location.");

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
										  CSFileManagerOptionsCreateDirectory)];

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
			   completionBlock:^(TDCAlertResponse buttonClicked, BOOL suppressed, id  _Nullable underlyingAlert) {
		if (suppressed) {
			[self _removeGroupContainerContentsForInstallation:installation];
		}
	}];

	[alert setButtonClickedBlock:^BOOL(TVCAlert *sender, TVCAlertResponseButton buttonClicked) {
		[TLOpenLink openWithString:@"https://help.codeux.com/textual/miscellaneous/Why-Did-Textual-Copy-Files-to-a-New-Location.kb" inBackground:NO];

		return NO;
	} forButton:TVCAlertResponseButtonThird];
}

+ (void)_notifyGroupContainerMigratedForStandaloneClassic
{
	[self _notifyGroupContainerMigratedForInstallation:TPCResourceManagerMigrationInstallationStandaloneClassic];
}

+ (void)_notifyGroupContainerMigratedForMacAppStore
{
	[self _notifyGroupContainerMigratedForInstallation:TPCResourceManagerMigrationInstallationMacAppStore];
}

#pragma mark -
#pragma mark Group Container Removal

+ (BOOL)_removeGroupContainerContentsForInstallation:(TPCResourceManagerMigrationInstallation)installation
{
	LogToConsoleInfo("Start: Remove group container for '%@'",
		[self _descriptionOfInstallation:installation]);

	NSURL *gcLocation = [self _groupContainerURLForInstallation:installation];

	if (gcLocation == nil) {
		LogToConsoleError("Cannot remove group container contents because of nil location.");

		return NO;
	}

	BOOL result = [self _removeGroupContainerContentsAtURL:gcLocation];

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

+ (BOOL)_removeGroupContainerContentsAtURL:(NSURL *)location
{
	NSParameterAssert(location != nil);

	LogToConsoleInfo("Removing group container contents at URL: %@", location);

	return [RZFileManager() trashContentsOfDirectoryAtURL:location];
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
		LogToConsoleFault("Group container for installation [%@] is nil."
						  "This should be impossible.",
			[self _descriptionOfInstallation:installation]);
	}

	return gcLocation;
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

+ (NSTimeInterval)_ageOfFileAtURL:(NSURL *)url
{
	NSParameterAssert(url != nil);

	NSError *error = nil;

	NSTimeInterval age = [url ageOfResourceWithError:&error];

	if (error) {
		/* This is purposely considered debug information as the user knowing
		 a file not existing is not an error when that is probable outcome. */
		LogToConsoleDebug("Error caught when calculating age of file: %@",
			error.localizedDescription);
	}

	return age;
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

+ (nullable NSURL *)preferencesStandaloneClassicURL
{
	NSURL *sourceURL = self.userHomeURL;

	return [sourceURL URLByAppendingPathComponent:@"/Library/Preferences/com.codeux.apps.textual.plist"];
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
