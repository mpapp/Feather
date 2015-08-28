#!/bin/bash

if [ $CONFIGURATION != "Release" ]
then
    echo "Setting version skipped."
    exit 0
fi

# This script sets version information in the Info.plist of a target to the version
# as returned by 'git describe'.
# Info: http://zargony.com/2014/08/10/automatic-versioning-in-xcode-with-git-describe
set -e
#--abbrev=4 will cause using four letters, or as many as are needed for uniquely describing the commit.
VERSION=`git describe --dirty --abbrev=4 | sed -e "s/^[^0-9]*//" | tr '[:lower:]' '[:upper:]'`
#--abbrev=0 suppresses using long formatted versions.
SHORT_VERSION=`git describe --abbrev=0 | sed -e "s/^[^0-9]*//"`

echo "Updating Info.plist version to: ${VERSION}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" -c "Set :CFBundleShortVersionString ${SHORT_VERSION}" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
