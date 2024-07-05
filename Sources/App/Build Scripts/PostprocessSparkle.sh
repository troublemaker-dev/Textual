#!/bin/bash

set -e

echo "Performing postprocessing on Sparkle framework"

cd "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"

rm -rf Sparkle.framework/Versions/B/XPCServices/Downloader.xpc

codesign -f -s "$CODE_SIGN_IDENTITY" -o runtime Sparkle.framework/Versions/B/XPCServices/Installer.xpc

codesign -f -s "$CODE_SIGN_IDENTITY" -o runtime Sparkle.framework/Versions/B/Autoupdate
codesign -f -s "$CODE_SIGN_IDENTITY" -o runtime Sparkle.framework/Versions/B/Updater.app

codesign -f -s "$CODE_SIGN_IDENTITY" -o runtime Sparkle.framework

exit 0
