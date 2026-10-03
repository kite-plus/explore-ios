#!/bin/sh
# Archives the app for release. With an App Store Connect API key in the
# environment (ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8, the key file's
# text) and APPLE_TEAM_ID, Xcode signs it with cloud-managed certificates
# and uploads it to App Store Connect, where it shows up in TestFlight.
# Without them it archives unsigned, which proves the release builds and
# ships nothing. RELEASE.md has the setup.
#
# A tag such as v0.1.1 sets the version, and the CI run the build number,
# so every upload carries a new one.
set -eu
cd "$(dirname "$0")/.."

out=${RUNNER_TEMP:-build}/release
rm -rf "$out"
mkdir -p "$out"
archive="$out/Explore.xcarchive"

set -- -project Explore.xcodeproj -scheme Explore -configuration Release \
    -destination generic/platform=iOS -archivePath "$archive" \
    APP_BUNDLE_ID="${APP_BUNDLE_ID:-plus.kite.explore}" \
    CURRENT_PROJECT_VERSION="${GITHUB_RUN_NUMBER:-1}.${GITHUB_RUN_ATTEMPT:-1}"
case "${GITHUB_REF_NAME:-}" in
    # A prerelease such as v0.2.0-rc.1 ships as 0.2.0: App Store versions
    # are numbers only.
    v[0-9]*) version=${GITHUB_REF_NAME#v} && set -- "$@" MARKETING_VERSION="${version%%-*}" ;;
esac

summary() {
    echo "$1"
    if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then echo "$1" >> "$GITHUB_STEP_SUMMARY"; fi
}

if [ -z "${ASC_KEY_ID:-}" ] || [ -z "${ASC_ISSUER_ID:-}" ] || [ -z "${ASC_KEY_P8:-}" ] || [ -z "${APPLE_TEAM_ID:-}" ]; then
    xcodebuild archive "$@" CODE_SIGNING_ALLOWED=NO
    summary "Signing is not set up, so the archive was built unsigned and nothing was uploaded. RELEASE.md says how to set it up."
    exit 0
fi

key="$out/AuthKey_$ASC_KEY_ID.p8"
trap 'rm -f "$key"' EXIT
printf '%s\n' "$ASC_KEY_P8" > "$key"

xcodebuild archive "$@" DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
    -allowProvisioningUpdates -authenticationKeyPath "$key" \
    -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"

cat > "$out/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>$APPLE_TEAM_ID</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF

xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$out/ExportOptions.plist" \
    -exportPath "$out/export" -allowProvisioningUpdates -authenticationKeyPath "$key" \
    -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
summary "Uploaded to App Store Connect. It appears in TestFlight once Apple has processed it."
