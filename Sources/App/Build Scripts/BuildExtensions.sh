#!/bin/bash

set -e

echo "Building using architecture: ${ARCHS}"

TEXTUAL_PRODUCT_LOCATION="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}"
TEXTUAL_PRODUCT_BINARY="${TARGET_BUILD_DIR}/${EXECUTABLE_PATH}"

plugins=(
    'Caffeine'
    'Chat Filter'
    'Smiley Converter'
    'System Profiler'
    'User Insights'
    'ZNC Additions'
)

for plugin in "${plugins[@]}"; do
    cd "${TEXTUAL_WORKSPACE_DIR}/Sources/Plugins/${plugin}"
    xcodebuild -target "$plugin Extension" \
        -configuration "${TEXTUAL_EXTENSION_BUILD_SCHEME}" \
        ARCHS="${ARCHS}" \
        CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY}" \
        DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
        PROVISIONING_PROFILE_SPECIFIER="" \
        TEXTUAL_WORKSPACE_DIR="${TEXTUAL_WORKSPACE_DIR}" \
        TEXTUAL_PRODUCT_LOCATION="${TEXTUAL_PRODUCT_LOCATION}" \
        TEXTUAL_PRODUCT_BINARY="${TEXTUAL_PRODUCT_BINARY}"

done

exit 0
