#!/bin/sh
# Builds a release of Dayloom for distribution outside the App Store: archives it,
# exports it signed with Developer ID (Xcode fetches a Developer ID provisioning
# profile carrying the iCloud container, which needs the Account Holder signed in
# to Xcode), notarizes it with Apple, staples the ticket, and checks the zip the
# way a user receives it.
#
# Needs an App Store Connect API key in the environment:
#   ASC_KEY_PATH   path to the AuthKey_<id>.p8 file
#   ASC_KEY_ID     the key's ID
#   ASC_ISSUER_ID  the issuer ID
#
# Produces build/Dayloom-<version>.zip and prints its SHA-256.
set -eu
cd "$(dirname "$0")/.."

fail() { echo "release: $*" >&2; exit 1; }

: "${ASC_KEY_PATH:?set ASC_KEY_PATH to the App Store Connect API key (.p8)}"
: "${ASC_KEY_ID:?set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
[ -f "$ASC_KEY_PATH" ] || fail "no key at $ASC_KEY_PATH"

version=$(xcodebuild -project agenda.xcodeproj -scheme agenda -configuration Release -showBuildSettings 2>/dev/null |
    sed -n 's/^ *MARKETING_VERSION = //p' | head -n 1)
[ -n "$version" ] || fail "couldn't read MARKETING_VERSION"

archive=build/Dayloom.xcarchive
export_dir=build/export
app=$export_dir/Dayloom.app
zip=build/Dayloom-$version.zip
rm -rf "$archive" "$export_dir" "$zip"

echo "==> archive $version"
xcodebuild archive -project agenda.xcodeproj -scheme agenda -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$archive" \
    -allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" \
    -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
    -quiet || fail "archive failed"

echo "==> export with Developer ID"
# Uses the account signed in to Xcode, not the API key: only the Account Holder may
# create the Developer ID provisioning profile that carries the iCloud container.
xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist scripts/ExportOptions.plist \
    -exportPath "$export_dir" -allowProvisioningUpdates -quiet || fail "export failed"
[ -d "$app" ] || fail "export produced no $app"

echo "==> check signature and entitlements"
codesign --verify --strict --deep --verbose=2 "$app"
codesign -dvv "$app" 2>&1 | grep -E "^(Authority|TeamIdentifier|Runtime Version)" | head -n 4
entitlements=$(codesign -d --entitlements - --xml "$app" 2>/dev/null)
for key in com.apple.developer.icloud-container-identifiers com.apple.security.app-sandbox \
           com.apple.security.network.client com.apple.security.network.server; do
    printf '%s' "$entitlements" | grep -q "$key" || fail "entitlement $key is missing"
done
printf '%s' "$entitlements" | grep -A1 "aps-environment" | grep -q production ||
    fail "aps-environment isn't production; CloudKit sync wouldn't receive changes"

echo "==> notarize"
ditto -c -k --keepParent "$app" "$zip"
xcrun notarytool submit "$zip" --key "$ASC_KEY_PATH" --key-id "$ASC_KEY_ID" \
    --issuer "$ASC_ISSUER_ID" --wait --timeout 30m

echo "==> staple and repackage"
xcrun stapler staple "$app"
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"

echo "==> verify the zip as a user receives it"
check=$(mktemp -d)
trap 'rm -rf "$check"' EXIT
ditto -x -k "$zip" "$check"
xcrun stapler validate "$check/Dayloom.app"
spctl --assess --type execute --verbose=2 "$check/Dayloom.app"
lipo -archs "$check/Dayloom.app/Contents/MacOS/Dayloom"

echo "==> $zip"
shasum -a 256 "$zip"
