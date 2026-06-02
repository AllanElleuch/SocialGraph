#!/bin/sh

# ci_post_clone.sh
#
# Xcode Cloud runs this automatically after cloning the repository, before the
# build/archive step. The Flutter SDK is not preinstalled on Xcode Cloud
# runners, and the generated files it produces (ios/Flutter/Generated.xcconfig,
# the CocoaPods Pods/ directory and its *.xcfilelist inputs/outputs) are
# git-ignored. Without this script the archive fails with:
#   could not find included file 'Generated.xcconfig' in search paths
#   Unable to load contents of file list: '.../Pods-Runner-frameworks-*.xcfilelist'
#
# So we install a pinned Flutter SDK, fetch packages (which generates
# Generated.xcconfig), and run pod install (which generates the xcfilelists).

set -e

# Keep this in sync with the team's local Flutter version.
FLUTTER_VERSION="3.41.6"
FLUTTER_CHANNEL="stable"

echo "===> Installing Flutter ${FLUTTER_VERSION} (${FLUTTER_CHANNEL})"
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

echo "===> Installing CocoaPods"
cd ios
pod install

echo "===> ci_post_clone.sh complete"
