#!/bin/bash
# Archive, sign, notarize and staple a distributable Relay.app, then zip it for release.
#
# This is the single source of truth for how a Relay build is cut. CI calls it with the same
# arguments a person would, so a release can always be produced from a laptop when Actions is
# unavailable, and so notarization problems can be debugged interactively instead of through
# push cycles.
#
# Credentials, all required:
#   A "Developer ID Application" identity in the keychain, plus an App Store Connect API key:
#     AC_API_KEY_ID, AC_API_ISSUER_ID, AC_API_KEY_PATH (a .p8 file)
#   Alternatively, set AC_KEYCHAIN_PROFILE to a profile stored with
#     xcrun notarytool store-credentials
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

version="$(tr -d '[:space:]' < VERSION)"
# The build number must increase with every build a tester can install, or macOS and Relay's
# own crash reports cannot tell two builds apart. Commit count is monotonic and needs no state.
build="${RELAY_BUILD_NUMBER:-$(git rev-list --count HEAD)}"
output="${RELAY_OUTPUT_DIR:-$repo_root/.build/release}"
archive="$output/Relay.xcarchive"
export_dir="$output/export"
app="$export_dir/Relay.app"
zip="$output/Relay-$version.zip"

if [[ ! -d "Packages/TerminalKit/Vendor/GhosttyKit.xcframework" ]]; then
    echo "libghostty is missing. Run Scripts/BuildGhostty.sh first." >&2
    exit 1
fi
if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    echo 'No "Developer ID Application" identity in the keychain. Create one at' >&2
    echo 'developer.apple.com → Certificates, and install it before releasing.' >&2
    exit 1
fi

# Scripts/BuildGhostty.sh vendors libghostty for the host architecture only, so the release is
# Apple Silicon only. To ship a universal app, build Ghostty with -Dxcframework-target=universal
# and drop the ARCHS override below.

# The command line settings below reach every target in the build, including the resource
# bundle SwiftPM generates for TerminalKit's Ghostty resources. That generated target is not
# part of Relay.xcodeproj and so inherits none of its signing settings, and manual signing
# without a team is an error, so the team has to be passed explicitly. ExportOptions.plist
# already records it for the export step; read it from there rather than naming it twice.
team="$(/usr/libexec/PlistBuddy -c 'Print :teamID' Scripts/ExportOptions.plist)"

echo "==> Relay $version ($build), arm64"
rm -rf "$output"
mkdir -p "$output"

echo "==> Archiving"
xcodebuild archive \
    -project Relay.xcodeproj \
    -scheme Relay \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$archive" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
    MARKETING_VERSION="$version" \
    CURRENT_PROJECT_VERSION="$build" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    DEVELOPMENT_TEAM="$team" \
    OTHER_CODE_SIGN_FLAGS="--timestamp"

echo "==> Exporting"
xcodebuild -exportArchive \
    -archivePath "$archive" \
    -exportOptionsPlist Scripts/ExportOptions.plist \
    -exportPath "$export_dir"

echo "==> Verifying the signature before asking Apple to look at it"
codesign --verify --deep --strict --verbose=2 "$app"
# Gatekeeper's own verdict. This still fails at this point for a build that is not yet
# notarized, so only the signing half is asserted here; the stapled check below is the real one.
codesign -dv --verbose=4 "$app" 2>&1 | grep -E "Authority|TeamIdentifier|Timestamp|flags" || true

echo "==> Notarizing"
ditto -c -k --keepParent "$app" "$zip"
auth=()
if [[ -n "${AC_KEYCHAIN_PROFILE:-}" ]]; then
    auth=(--keychain-profile "$AC_KEYCHAIN_PROFILE")
else
    : "${AC_API_KEY_ID:?set AC_API_KEY_ID or AC_KEYCHAIN_PROFILE}"
    : "${AC_API_ISSUER_ID:?set AC_API_ISSUER_ID}"
    : "${AC_API_KEY_PATH:?set AC_API_KEY_PATH}"
    auth=(--key "$AC_API_KEY_PATH" --key-id "$AC_API_KEY_ID" --issuer "$AC_API_ISSUER_ID")
fi

# JSON rather than the human output: the id is needed to fetch Apple's reasons on a rejection,
# and --wait prints several records that are ambiguous to scrape.
result="$(xcrun notarytool submit "$zip" "${auth[@]}" --wait --timeout 30m --output-format json)"
echo "$result"
status="$(printf '%s' "$result" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))')"
submission="$(printf '%s' "$result" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("id",""))')"
if [[ "$status" != "Accepted" ]]; then
    echo "==> Notarization failed with status: ${status:-unknown}. Apple's reasons:" >&2
    [[ -n "$submission" ]] && xcrun notarytool log "$submission" "${auth[@]}" >&2 || true
    exit 1
fi

echo "==> Stapling"
xcrun stapler staple "$app"
xcrun stapler validate "$app"
# What a tester's Mac will actually decide when they double-click it.
spctl --assess --type execute --verbose=4 "$app"

# Re-zip: the notarized ticket is stapled into the app, not into the zip that was uploaded.
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"

echo
echo "==> Relay $version ($build) is notarized and stapled"
echo "    $zip"
