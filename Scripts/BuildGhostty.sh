#!/bin/bash
# Build the official pinned embedding library; run once before opening Relay.xcodeproj.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
zig_bin="${ZIG:-zig}"
if [[ "$("$zig_bin" version)" != "0.14.1" ]]; then
    echo 'Ghostty 1.2.3 requires Zig 0.14.1. Set ZIG to that compiler’s path.' >&2
    exit 1
fi
# Zig 0.14.1 matches SDK stub targets literally, and the Xcode 26.4 SDK renamed its
# arm64-macos entries to arm64e-macos, so linking against it fails with every libSystem
# symbol undefined (ziglang/zig#31658, fixed only in Zig 0.16). Build against the newest
# toolchain whose stub still advertises this machine's architecture.
arch="$(uname -m)"
supports_zig_linking() {
    local sdk
    sdk="$(DEVELOPER_DIR="$1" SDKROOT= xcrun --sdk macosx --show-sdk-path 2>/dev/null)" || return 1
    [[ -n "$sdk" ]] && grep -q "$arch-macos" "$sdk/usr/lib/libSystem.tbd" 2>/dev/null
}
if [[ -z "${DEVELOPER_DIR:-}" ]]; then
    for candidate in $(ls -d /Applications/Xcode*.app 2>/dev/null | sort -Vr); do
        if supports_zig_linking "$candidate/Contents/Developer"; then
            export DEVELOPER_DIR="$candidate/Contents/Developer"
            break
        fi
    done
fi
if ! supports_zig_linking "${DEVELOPER_DIR:-$(xcode-select -p)}"; then
    echo 'No installed Xcode ships an SDK that Zig 0.14.1 can link against; Xcode 26.3 or older is required for this step.' >&2
    exit 1
fi
export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
echo "Building libghostty against $SDKROOT"

build_root="${RELAY_GHOSTTY_BUILD_DIR:-$repo_root/.build/ghostty}"
mkdir -p "$build_root"
archive="$build_root/ghostty-1.2.3.tar.gz"
if [[ ! -f "$archive" ]]; then
    curl --fail --location --retry 3 'https://release.files.ghostty.org/1.2.3/ghostty-1.2.3.tar.gz' -o "$archive"
fi
printf '%s  %s\n' '559770fe9773161e93e3dd9177d916e27037d7f548edcf6186eabc571c0e520b' "$archive" | shasum -a 256 -c -
source_root="$build_root/source"
if [[ ! -d "$source_root" ]]; then
    mkdir -p "$source_root"
    tar -xzf "$archive" -C "$source_root" --strip-components=1
fi
cd "$source_root"
"$zig_bin" build -Doptimize=ReleaseFast -Demit-macos-app=false \
    -Dxcframework-target=native -Demit-docs=false -Demit-themes=false -Di18n=false \
    --global-cache-dir "$build_root/zig-cache"
package="$repo_root/Packages/TerminalKit"
mkdir -p "$package/Vendor" "$package/Sources/TerminalKit/Resources"
ditto macos/GhosttyKit.xcframework "$package/Vendor/GhosttyKit.xcframework"
ditto zig-out/share/ghostty "$package/Sources/TerminalKit/Resources/ghostty"
ditto zig-out/share/terminfo "$package/Sources/TerminalKit/Resources/terminfo"
cp LICENSE "$package/Vendor/Ghostty-LICENSE"
echo "Built libghostty 1.2.3 for $(uname -m). Relay.xcodeproj is ready to build."
