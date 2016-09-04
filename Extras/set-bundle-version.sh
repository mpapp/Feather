#!/bin/bash

# AppStoreRelease should *not* modify the version.
if [ $CONFIGURATION != "Release" ] && [ $CONFIGURATION != "ReleaseSetapp" ]
then
    echo "Setting version skipped."
    exit 0
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# This script sets version information in the Info.plist of a target to the version
# as returned by 'git describe'.
# Info: http://zargony.com/2014/08/10/automatic-versioning-in-xcode-with-git-describe
set -e
#--abbrev=4 will cause using four letters, or as many as are needed for uniquely describing the commit.
VERSION=`${DIR}/get-version.sh`
#--abbrev=0 suppresses using long formatted versions.
SHORT_VERSION=`${DIR}/get-short-version.sh`

echo "Updating Info.plist version to: ${VERSION}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" -c "Set :CFBundleShortVersionString ${SHORT_VERSION}" "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
