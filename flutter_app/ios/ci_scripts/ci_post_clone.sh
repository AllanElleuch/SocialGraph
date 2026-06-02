#!/bin/sh

# ci_post_clone.sh
#
# Xcode Cloud runs this automatically after cloning the repository, before the
# build/archive step. The Flutter SDK is not preinstalled on Xcode Cloud
# runners, and the files it generates (ios/Flutter/Generated.xcconfig, the
# CocoaPods Pods/ directory and its *.xcfilelist inputs) are git-ignored.
# Without this script the archive fails with:
#   could not find included file 'Generated.xcconfig' in search paths
#   Unable to load contents of file list: '.../Pods-Runner-frameworks-*.xcfilelist'
#
# Dependency caching: Xcode Cloud AUTOMATICALLY caches and restores CocoaPods
# (and Swift Package / Homebrew) dependencies between builds in a workflow —
# there is no manual toggle. Two things make that cache effective, and both are
# in place here:
#   1. ios/Podfile.lock is committed, so `pod install` resolves deterministically
#      and the cached pods stay valid until the lockfile changes.
#   2. This script never runs `pod cache clean` / deletes Pods/, so the restored
#      cache (incl. the prebuilt FirebaseFirestore binary frameworks pulled via
#      the Podfile) is reused instead of re-downloaded.
# The Flutter SDK clone below is a custom step Xcode Cloud does NOT cache, so it
# is kept shallow (--depth 1, single tag) to minimise its cost on each run.

set -e

# Keep this in sync with the team's local Flutter version.
FLUTTER_VERSION="3.41.6"

echo "===> Installing Flutter ${FLUTTER_VERSION}"
git clone https://github.com/flutter/flutter.git --depth 1 -b "${FLUTTER_VERSION}" "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

flutter --version
flutter config --no-analytics
flutter precache --ios

# Xcode Cloud checks the repo out at $CI_PRIMARY_REPOSITORY_PATH. The Flutter
# project lives in the flutter_app/ subdirectory of this repository.
echo "===> Fetching Flutter packages"
cd "$CI_PRIMARY_REPOSITORY_PATH/flutter_app"
flutter pub get

# Generate ios/Flutter/Generated.xcconfig without doing a full build.
echo "===> Generating iOS build configuration"
flutter build ios --config-only --release --no-codesign

# Install a current CocoaPods via Homebrew (Homebrew is cached by Xcode Cloud).
# A recent CocoaPods is required to resolve the git-sourced prebuilt
# FirebaseFirestore binary frameworks declared in the Podfile.
echo "===> Installing CocoaPods"
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

echo "===> Installing iOS pods"
cd ios
pod install

echo "===> ci_post_clone.sh complete"
