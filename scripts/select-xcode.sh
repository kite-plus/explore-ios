#!/bin/sh
# Switches a CI runner to the newest release of Xcode it has; the app needs
# the iOS 26 SDK or later. Betas and release candidates are left out.
set -eu

xcode=$(ls -d /Applications/Xcode_*.app | grep -viE 'beta|_rc' | sort -V | tail -n 1)
sudo xcode-select --switch "$xcode"
xcodebuild -version
